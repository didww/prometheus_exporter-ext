# frozen_string_literal: true

require 'prometheus_exporter/ext/instrumentation/active_job'
require 'active_support/testing/time_helpers'
require_relative '../../../support/active_job_test_job'

RSpec.describe PrometheusExporter::Ext::Instrumentation::ActiveJob do
  include ActiveSupport::Testing::TimeHelpers

  before do
    ActiveJob::Base.queue_adapter.enqueued_jobs = []
    described_class.subscribe
  end

  after do
    described_class.unsubscribe
    travel_back
  end

  let(:test_adapter) { 'ActiveJob::QueueAdapters::TestAdapter' }

  def safe_subject
    subject
  rescue StandardError
    nil
  end

  describe 'on_error handler' do
    subject do
      TestJob.perform_later
    end

    let(:client) { instance_double(PrometheusExporter::Client) }
    let(:errors) { [] }

    before do
      allow(client).to receive(:send_json).and_raise(RuntimeError, 'boom')
      described_class.subscribe(client:, on_error: ->(error) { errors << error })
    end

    it 'passes the exception to the handler and does not raise it' do
      expect { subject }.not_to raise_error
      expect(errors.map(&:message)).to eq(['boom'])
    end
  end

  describe 'enqueue job' do
    subject do
      TestJob.set(job_set_opts).perform_later(**enqueue_opts)
    end

    let(:job_set_opts) { {} }
    let(:enqueue_opts) { {} }

    it 'sends prometheus metrics' do
      expect { subject }.to send_metrics(
        type: 'active_job',
        labels: { job_class: 'TestJob', adapter: test_adapter, queue: 'default' },
        enqueued_total: 1
      )
    end

    context 'with wait' do
      let(:job_set_opts) do
        super().merge wait: 1.hour
      end

      it 'sends prometheus metrics with scheduled label' do
        expect { subject }.to send_metrics(
          type: 'active_job',
          labels: {
            job_class: 'TestJob',
            adapter: test_adapter,
            queue: 'default',
            scheduled: 'true'
          },
          enqueued_total: 1
        )
      end
    end

    context 'with enqueue error' do
      let(:enqueue_opts) do
        super().merge enqueue_error: TestJob::TestEnqueueError.new('enqueue failed')
      end

      it 'sends prometheus metrics with the error class name, not its message' do
        expect { safe_subject }.to send_metrics(
          type: 'active_job',
          labels: { job_class: 'TestJob', adapter: test_adapter, queue: 'default', error: 'TestJob::TestEnqueueError' },
          fail_enqueued_total: 1
        )
      end

      it 'raises exception' do
        expect { subject }.to raise_error(TestJob::TestEnqueueError)
      end
    end
  end

  describe 'enqueue jobs' do
    subject do
      ActiveJob.perform_all_later(jobs)
    end

    let(:jobs) do
      Array.new(2) { TestJob.new }
    end

    before do
      jobs[1].scheduled_at = 1.hour.from_now
    end

    it 'sends prometheus metrics' do
      expect { subject }.to send_metrics(
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', adapter: test_adapter, queue: 'default' },
          enqueued_total: 1
        },
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', adapter: test_adapter, queue: 'default', scheduled: 'true' },
          enqueued_total: 1
        }
      )
    end
  end

  describe 'perform job' do
    subject do
      TestJob.perform_now(job)
    end

    let(:job) { TestJob.new(error: job_error) }
    let(:job_error) { nil }

    before do
      job.enqueued_at = 2.seconds.ago
    end

    it 'sends prometheus metrics' do
      expect { subject }.to send_metrics(
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
          latency_seconds: be_positive
        },
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
          executed_total: 1,
          success_total: 1,
          duration_seconds: be_positive
        }
      )
    end

    context 'when job had executions' do
      before do
        job.executions = 2
      end

      it 'sends prometheus metrics' do
        expect { subject }.to send_metrics(
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '3', queue: 'default' },
            latency_seconds: be_positive
          },
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '3', queue: 'default' },
            executed_total: 1,
            success_total: 1,
            duration_seconds: be_positive
          }
        )
      end
    end

    context 'when job was enqueued with wait' do
      before do
        job.enqueued_at = Time.current
        job.scheduled_at = 1.hour.from_now.change(usec: 0)
      end

      it 'measures latency from scheduled_at, not from enqueued_at' do
        travel_to(job.scheduled_at + 2.seconds) do
          expect { subject }.to send_metrics(
            {
              type: 'active_job',
              labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
              latency_seconds: be_within(0.001).of(2)
            },
            {
              type: 'active_job',
              labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
              executed_total: 1,
              success_total: 1,
              duration_seconds: be_positive
            }
          )
        end
      end

      it 'reports zero latency when the job is picked up before scheduled_at' do
        travel_to(job.scheduled_at - 1.second) do
          expect { subject }.to send_metrics(
            {
              type: 'active_job',
              labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
              latency_seconds: 0
            },
            {
              type: 'active_job',
              labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
              executed_total: 1,
              success_total: 1,
              duration_seconds: be_positive
            }
          )
        end
      end
    end

    context 'when job raises suppressed exception' do
      let(:job_error) { TestJob::TestSuppressError }

      it 'sends prometheus metrics' do
        expect { subject }.to send_metrics(
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            latency_seconds: be_positive
          },
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            executed_total: 1,
            success_total: 1,
            duration_seconds: be_positive
          }
        )
      end
    end

    context 'when job raises retryable exception' do
      let(:job_error) { TestJob::TestRetryError }

      it 'sends prometheus metrics' do
        expect { subject }.to send_metrics(
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            latency_seconds: be_positive
          },
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, queue: 'default', scheduled: 'true' },
            enqueued_total: 1
          },
          {
            type: 'active_job',
            labels: {
              job_class: 'TestJob', adapter: test_adapter,
              executions: '1',
              queue: 'default',
              error: 'TestJob::TestRetryError'
            },
            retried_total: 1
          },
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            executed_total: 1,
            success_total: 1,
            duration_seconds: be_positive
          }
        )
      end

      context 'when already retried max times' do
        before do
          job.executions = TestJob::MAX_RETRIES + 2
          job.exception_executions[exception_executions_key] = TestJob::MAX_RETRIES
        end

        # active_job counts retry attempts per `retry_on` call.
        let(:exception_executions_key) { [TestJob::TestRetryError].to_s }
        let(:executions) { (job.executions + 1).to_s }

        it 'raises exception' do
          expect { subject }.to raise_error(TestJob::TestRetryError)
        end

        it 'sends prometheus metrics' do
          expect { safe_subject }.to send_metrics(
            {
              type: 'active_job',
              labels: { job_class: 'TestJob', adapter: test_adapter, executions:, queue: 'default' },
              latency_seconds: be_positive
            },
            {
              type: 'active_job',
              labels: {
                job_class: 'TestJob', adapter: test_adapter,
                executions:,
                queue: 'default',
                error: 'TestJob::TestRetryError'
              },
              retry_stopped_total: 1
            },
            {
              type: 'active_job',
              labels: { job_class: 'TestJob', adapter: test_adapter, executions:, queue: 'default' },
              executed_total: 1,
              duration_seconds: be_positive
            },
            {
              type: 'active_job',
              labels: {
                job_class: 'TestJob', adapter: test_adapter,
                executions:,
                queue: 'default',
                error: 'TestJob::TestRetryError'
              },
              failed_total: 1
            }
          )
        end
      end
    end

    context 'when job raises discardable exception' do
      let(:job_error) { TestJob::TestDiscardError }

      it 'sends prometheus metrics' do
        expect { subject }.to send_metrics(
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            latency_seconds: be_positive
          },
          {
            type: 'active_job',
            labels: {
              job_class: 'TestJob', adapter: test_adapter,
              executions: '1',
              queue: 'default',
              error: 'TestJob::TestDiscardError'
            },
            discarded_total: 1
          },
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            executed_total: 1,
            success_total: 1,
            duration_seconds: be_positive
          }
        )
      end
    end

    context 'when job raises unexpected exception' do
      let(:job_error) { RuntimeError }

      it 'raises exception' do
        expect { subject }.to raise_error(RuntimeError)
      end

      it 'sends prometheus metrics' do
        expect { safe_subject }.to send_metrics(
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            latency_seconds: be_positive
          },
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            executed_total: 1,
            duration_seconds: be_positive
          },
          {
            type: 'active_job',
            labels: {
              job_class: 'TestJob', adapter: test_adapter,
              executions: '1',
              queue: 'default',
              error: 'RuntimeError'
            },
            failed_total: 1
          }
        )
      end
    end
  end
end
