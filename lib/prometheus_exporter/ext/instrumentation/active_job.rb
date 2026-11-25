# frozen_string_literal: true

require 'time'
require 'active_support'
require 'active_support/notifications'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/time'
require_relative 'base_stats'

module PrometheusExporter::Ext::Instrumentation
  class ActiveJob < BaseStats
    self.type = 'active_job'

    QUEUE_IVAR = :@_prometheus_exporter_queue

    ERROR_EVENTS = {
      'enqueue_retry.active_job' => :collect_enqueue_retried, # job retried due to error
      'discard.active_job' => :collect_discarded, # job discarded due to error
      'retry_stopped.active_job' => :collect_retry_stopped # retries stopped after max attempts reached
    }.freeze

    class << self
      # @see https://guides.rubyonrails.org/active_support_instrumentation.html#active-job
      def subscribe(**)
        unsubscribe # ensures we don't double subscribe
        instance = new(**)
        @subscribers = []

        subscribe_enqueue_events(instance)
        subscribe_perform_events(instance)
        subscribe_error_events(instance)
      end

      def unsubscribe
        return unless defined?(@subscribers)

        @subscribers.each do |sub_id|
          ::ActiveSupport::Notifications.unsubscribe(sub_id)
        end
        @subscribers = []
      end

      private

      def subscribe_enqueue_events(instance)
        # job enqueued, with or without wait
        ['enqueue.active_job', 'enqueue_at.active_job'].each do |name|
          subscribe_event(name) do |event|
            payload = event.payload
            instance.collect_enqueued(
              jobs: [payload[:job]], adapter: payload[:adapter], exception_object: payload[:exception_object]
            )
          end
        end

        # multiple jobs enqueued at once
        subscribe_event 'enqueue_all.active_job' do |event|
          payload = event.payload
          instance.collect_enqueued(
            jobs: payload[:jobs],
            adapter: payload[:adapter],
            exception_object: payload[:exception_object],
            enqueued_count: payload[:enqueued_count]
          )
        end
      end

      def subscribe_perform_events(instance)
        # job perform started
        subscribe_event 'perform_start.active_job' do |event|
          instance.collect_started(job: event.payload[:job], adapter: event.payload[:adapter])
        end

        # job perform completed (both success and failure)
        monotonic_subscribe_event 'perform.active_job' do |event|
          payload = event.payload
          instance.collect_performed(
            job: payload[:job],
            adapter: payload[:adapter],
            exception: payload[:exception],
            duration_ms: event.duration,
            aborted: payload[:aborted]
          )
        end
      end

      def subscribe_error_events(instance)
        ERROR_EVENTS.each do |name, handler|
          subscribe_event(name) do |event|
            payload = event.payload
            instance.public_send(handler, job: payload[:job], adapter: payload[:adapter], error: payload[:error])
          end
        end
      end

      def subscribe_event(name, &)
        sub_id = ::ActiveSupport::Notifications.subscribe(name, &)
        @subscribers << sub_id
        sub_id
      end

      def monotonic_subscribe_event(name, &)
        sub_id = ::ActiveSupport::Notifications.monotonic_subscribe(name, &)
        @subscribers << sub_id
        sub_id
      end
    end

    def collect_enqueued(jobs:, adapter:, exception_object: nil, enqueued_count: nil)
      safe_collect do
        jobs.zip(enqueued_flags(jobs, enqueued_count)).each do |job, enqueued|
          if enqueued
            # A retry re-enqueues a job that already ran; retried_total counts it.
            next if job.executions.to_i.positive?

            collect_data(
              {
                labels: job_labels(job, adapter, scheduled: job.scheduled_at.present? ? 'true' : nil),
                enqueued_total: 1
              }
            )
          else
            enqueue_error = exception_object || job.enqueue_error
            collect_data(
              {
                labels: job_labels(job, adapter, error: enqueue_error&.class&.name),
                fail_enqueued_total: 1
              }
            )
          end
        end
      end
    end

    def collect_started(job:, adapter:, now: Time.current)
      safe_collect do
        job.instance_variable_set(QUEUE_IVAR, job.queue_name.to_s)
        latency_seconds = calculate_latency(job.enqueued_at, job.scheduled_at, now)
        if latency_seconds.present?
          collect_data(
            {
              labels: job_labels(job, adapter, executions: job.executions.to_s),
              latency_seconds:
            }
          )
        end
      end
    end

    def collect_performed(job:, adapter:, exception:, duration_ms:, aborted: false)
      safe_collect do
        # Rails < 8.1 retry_on(queue:) changes job.queue_name before perform.active_job is published.
        queue = job.instance_variable_get(QUEUE_IVAR) || job.queue_name.to_s
        success = exception.blank? && !aborted
        collect_data(
          {
            labels: job_labels(job, adapter, queue:, executions: job.executions.to_s),
            executed_total: 1,
            success_total: success ? 1 : nil,
            duration_seconds: ms2s(duration_ms)
          }.compact
        )

        if exception.present?
          collect_data(
            {
              labels: job_labels(job, adapter, queue:, executions: job.executions.to_s, error: exception.first.to_s),
              failed_total: 1
            }
          )
        end
      end
    end

    def collect_enqueue_retried(job:, adapter:, error:)
      safe_collect do
        # Rails publishes enqueue_retry.active_job even when the re-enqueue failed.
        collect_data({ labels: error_labels(job, adapter, error), retried_total: 1 }) if job.successfully_enqueued?
      end
    end

    def collect_discarded(job:, adapter:, error:)
      safe_collect { collect_data({ labels: error_labels(job, adapter, error), discarded_total: 1 }) }
    end

    def collect_retry_stopped(job:, adapter:, error:)
      safe_collect { collect_data({ labels: error_labels(job, adapter, error), retry_stopped_total: 1 }) }
    end

    private

    # Adapters implementing enqueue_all (e.g. Sidekiq) may report only enqueued_count without setting
    # successfully_enqueued on each job. Then the totals follow enqueued_count, but which jobs failed is unknown,
    # so the first enqueued_count jobs are counted as enqueued.
    def enqueued_flags(jobs, enqueued_count)
      flags = jobs.map(&:successfully_enqueued?)
      return flags if enqueued_count.nil? || flags.any?

      count = enqueued_count.to_i
      jobs.each_index.map { |index| index < count }
    end

    def error_labels(job, adapter, error)
      job_labels(job, adapter, executions: job.executions.to_s, error: error&.class&.name)
    end

    def job_labels(job, adapter, queue: job.queue_name.to_s, **extra)
      {
        job_class: job.class.to_s,
        adapter: adapter.class.name,
        queue:,
        **extra
      }.compact_blank
    end

    def ms2s(milliseconds)
      milliseconds = milliseconds.to_f
      return 0 if milliseconds.zero?

      (milliseconds / 1000.0).round(3)
    end

    # A scheduled job becomes runnable at scheduled_at, so the delay it was asked to wait is not latency.
    def calculate_latency(enqueued_at, scheduled_at, now)
      runnable_at = [enqueued_at, scheduled_at].compact_blank.map { |time| parse_time(time) }.max
      return nil if runnable_at.nil?

      [now - runnable_at, 0].max
    end

    def parse_time(time)
      time.is_a?(String) ? Time.parse(time).utc : time
    end
  end
end
