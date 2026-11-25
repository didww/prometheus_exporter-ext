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

    context 'when the adapter enqueues in bulk without setting successfully_enqueued' do
      let(:adapter_class) do
        Class.new do
          def enqueue_all(jobs)
            jobs.size
          end

          def enqueue(_job)
            nil
          end

          def enqueue_at(_job, _timestamp)
            nil
          end
        end
      end

      let!(:original_adapter) { TestJob.queue_adapter }

      before do
        stub_const('BulkWithoutFlagsAdapter', adapter_class)
        TestJob.queue_adapter = BulkWithoutFlagsAdapter.new
      end

      after do
        TestJob.queue_adapter = original_adapter
      end

      it 'counts the jobs as enqueued using the enqueued_count payload' do
        expect { subject }.to send_metrics(
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: 'BulkWithoutFlagsAdapter', queue: 'default' },
            enqueued_total: 1
          },
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: 'BulkWithoutFlagsAdapter', queue: 'default', scheduled: 'true' },
            enqueued_total: 1
          }
        )
      end
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

    context 'when a before_perform callback aborts the job' do
      subject do
        AbortedTestJob.perform_now
      end

      it 'does not count the job as successful' do
        expect { subject }.to send_metrics(
          {
            type: 'active_job',
            labels: { job_class: 'AbortedTestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            executed_total: 1,
            duration_seconds: be >= 0
          }
        )
      end
    end

    context 'when job retries without an error' do
      subject do
        RetryWithoutErrorTestJob.perform_now(error: RetryWithoutErrorTestJob::RetryWithoutErrorError)
      end

      it 'sends retried_total without an error label' do
        expect { subject }.to send_metrics(
          {
            type: 'active_job',
            labels: { job_class: 'RetryWithoutErrorTestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            retried_total: 1
          },
          {
            type: 'active_job',
            labels: { job_class: 'RetryWithoutErrorTestJob', adapter: test_adapter, executions: '1', queue: 'default' },
            executed_total: 1,
            success_total: 1,
            duration_seconds: be_positive
          }
        )
      end
    end
  end

  describe 'collecting directly' do
    let(:instrumentation) { described_class.new }
    let(:adapter) { ActiveJob::Base.queue_adapter }
    let(:job) { TestJob.new }

    describe '#collect_enqueue_retried' do
      subject do
        instrumentation.collect_enqueue_retried(job:, adapter:, error: StandardError.new)
      end

      it 'does not count a retry whose re-enqueue failed' do
        job.successfully_enqueued = false
        expect { subject }.not_to send_metrics
      end

      it 'counts a retry whose re-enqueue succeeded' do
        job.successfully_enqueued = true
        expect { subject }.to send_metrics(
          {
            type: 'active_job',
            labels: {
              job_class: 'TestJob', adapter: test_adapter,
              executions: '0',
              queue: 'default',
              error: 'StandardError'
            },
            retried_total: 1
          }
        )
      end
    end

    describe '#collect_performed' do
      it 'keeps the queue the job started on when retry_on changed it' do
        instrumentation.collect_started(job:, adapter:)
        job.queue_name = 'low'

        expect { instrumentation.collect_performed(job:, adapter:, exception: nil, duration_ms: 1) }.to send_metrics(
          {
            type: 'active_job',
            labels: { job_class: 'TestJob', adapter: test_adapter, executions: '0', queue: 'default' },
            executed_total: 1,
            success_total: 1,
            duration_seconds: be_positive
          }
        )
      end
    end
  end
end
