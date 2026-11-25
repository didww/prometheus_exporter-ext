# frozen_string_literal: true

require 'prometheus_exporter/metric'
require_relative '../../ext'

module PrometheusExporter::Ext::Metric
  # Counter that drops a label set not updated for `ttl` seconds. Same removing strategy as GaugeWithExpire.
  class CounterWithExpire < PrometheusExporter::Metric::Counter
    class << self
      def default_ttl
        60
      end
    end

    attr_reader :ttl, :expiration_times

    def initialize(name, help, opts = {})
      super(name, help)
      @ttl = opts[:ttl] || self.class.default_ttl
      raise ArgumentError, ':ttl must be numeric' unless ttl.is_a?(Numeric)
      raise ArgumentError, ":ttl must be greater than zero: #{ttl.inspect}" unless ttl.positive?
    end

    def reset!
      @expiration_times = {}
      super
    end

    def metric_text
      expire
      super
    end

    def to_h
      expire
      super
    end

    def remove(labels)
      expiration_times.delete(labels)
      super
    end

    def observe(increment = 1, labels = {})
      drop_if_stale(labels)
      result = super
      touch(labels)
      result
    end

    def increment(labels = {}, value = 1)
      drop_if_stale(labels)
      result = super
      touch(labels)
      result
    end

    def decrement(labels = {}, value = 1)
      drop_if_stale(labels)
      result = super
      touch(labels)
      result
    end

    def reset(labels = {}, value = 0)
      drop_if_stale(labels)
      result = super
      touch(labels)
      result
    end

    def expire
      now = now_time
      expiration_times.delete_if do |labels, expired_at|
        next false if expired_at >= now

        data.delete(labels)
        true
      end
    end

    private

    # A series that expired but was not read yet must restart from zero.
    def drop_if_stale(labels)
      expired_at = expiration_times[labels]
      return if expired_at.nil? || expired_at >= now_time

      data.delete(labels)
      expiration_times.delete(labels)
    end

    def touch(labels)
      expiration_times[labels] = now_time + ttl
    end

    def now_time
      ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end
  end
end
