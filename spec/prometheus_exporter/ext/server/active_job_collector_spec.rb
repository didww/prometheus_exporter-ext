# frozen_string_literal: true

require 'prometheus_exporter/ext/server/active_job_collector'

RSpec.describe PrometheusExporter::Ext::Server::ActiveJobCollector do
  describe '#collect' do
    subject do
      collector.collect(deep_stringify_keys(metric))
    end

    let(:collector) { described_class.new }

    context 'with enqueued metric' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '0', queue: 'default' },
          enqueued_total: 1
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .empty,
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .empty,
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .empty,
          a_counter_metric('active_job_latency_seconds')
            .empty
        )
      end
    end

    context 'with executed metric' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '1', queue: 'default' },
          executed_total: 1,
          duration_seconds: 2.5
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .empty,
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .empty,
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .with(2.5, metric[:labels]),
          a_counter_metric('active_job_latency_seconds')
            .empty
        )
      end
    end

    context 'with success metric' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '1', queue: 'default' },
          success_total: 1,
          duration_seconds: 1.2
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .empty,
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .empty,
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .with(1.2, metric[:labels]),
          a_counter_metric('active_job_latency_seconds')
            .empty
        )
      end
    end

    context 'with failed metric' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '1', queue: 'default', failure_reason: 'RuntimeError' },
          failed_total: 1
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .empty,
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .empty,
          a_counter_metric('active_job_failed_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_success_total')
            .empty,
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .empty,
          a_counter_metric('active_job_latency_seconds')
            .empty
        )
      end
    end

    context 'with latency metric' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '1', queue: 'default' },
          latency_seconds: 5.3
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .empty,
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .empty,
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .empty,
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .empty,
          a_counter_metric('active_job_latency_seconds')
            .with(5.3, metric[:labels])
        )
      end
    end

    context 'with fail_enqueued metric' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '0', queue: 'default', failure_reason: 'ConnectionError' },
          fail_enqueued_total: 1
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .empty,
          a_counter_metric('active_job_fail_enqueued_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_executed_total')
            .empty,
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .empty,
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .empty,
          a_counter_metric('active_job_latency_seconds')
            .empty
        )
      end
    end

    context 'with retried metric' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '2', queue: 'default', error: 'some error' },
          retried_total: 1
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .empty,
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .empty,
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .empty,
          a_counter_metric('active_job_retried_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .empty,
          a_counter_metric('active_job_latency_seconds')
            .empty
        )
      end
    end

    context 'with retry_stopped metric' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '3', queue: 'default', error: 'RuntimeError' },
          retry_stopped_total: 1
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .empty,
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .empty,
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .empty,
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .empty,
          a_counter_metric('active_job_latency_seconds')
            .empty
        )
      end
    end

    context 'with discarded metric' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '1', queue: 'default', error: 'some error' },
          discarded_total: 1
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .empty,
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .empty,
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .empty,
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_duration_seconds')
            .empty,
          a_counter_metric('active_job_latency_seconds')
            .empty
        )
      end
    end

    context 'with combined metrics' do
      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '1', queue: 'default' },
          executed_total: 1,
          success_total: 1,
          duration_seconds: 1.5,
          latency_seconds: 2.1
        }
      end

      it 'observes correct metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .empty,
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .with(1, metric[:labels]),
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .with(1.5, metric[:labels]),
          a_counter_metric('active_job_latency_seconds')
            .with(2.1, metric[:labels])
        )
      end
    end

    context 'when collector already has data' do
      before do
        collector.collect(deep_stringify_keys(old_same_labels))
        collector.collect(deep_stringify_keys(old_other_labels))
      end

      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '1', queue: 'default' },
          executed_total: 1,
          success_total: 1,
          duration_seconds: 0.5,
          latency_seconds: 1.2
        }
      end

      let(:old_same_labels) do
        {
          type: 'active_job',
          labels: { job_class: 'TestJob', executions: '1', queue: 'default' },
          executed_total: 2,
          success_total: 2,
          duration_seconds: 3.0,
          latency_seconds: 2.5
        }
      end

      let(:old_other_labels) do
        {
          type: 'active_job',
          labels: { job_class: 'OtherJob', executions: '0', queue: 'high' },
          enqueued_total: 5
        }
      end

      it 'observes correct cumulative metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .with(5, old_other_labels[:labels]),
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .with(3, metric[:labels]),
          a_counter_metric('active_job_failed_total')
            .empty,
          a_counter_metric('active_job_success_total')
            .with(3, metric[:labels]),
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .with(3.5, metric[:labels]),
          a_counter_metric('active_job_latency_seconds')
            .with(3.7, metric[:labels])
        )
      end
    end

    context 'when multiple different jobs are collected' do
      before do
        collector.collect(deep_stringify_keys(first_job))
        collector.collect(deep_stringify_keys(second_job))
      end

      let(:metric) do
        {
          type: 'active_job',
          labels: { job_class: 'ThirdJob', executions: '2', queue: 'low' },
          failed_total: 1
        }
      end

      let(:first_job) do
        {
          type: 'active_job',
          labels: { job_class: 'FirstJob', executions: '0', queue: 'default' },
          enqueued_total: 10
        }
      end

      let(:second_job) do
        {
          type: 'active_job',
          labels: { job_class: 'SecondJob', executions: '1', queue: 'high' },
          executed_total: 3,
          success_total: 2,
          failed_total: 1,
          duration_seconds: 5.5,
          latency_seconds: 1.8
        }
      end

      it 'observes all metrics correctly' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_counter_metric('active_job_enqueued_total')
            .with(10, first_job[:labels]),
          a_counter_metric('active_job_fail_enqueued_total')
            .empty,
          a_counter_metric('active_job_executed_total')
            .with(3, second_job[:labels]),
          a_counter_metric('active_job_failed_total')
            .with(1, second_job[:labels])
            .with(1, metric[:labels]),
          a_counter_metric('active_job_success_total')
            .with(2, second_job[:labels]),
          a_counter_metric('active_job_retried_total')
            .empty,
          a_counter_metric('active_job_retry_stopped_total')
            .empty,
          a_counter_metric('active_job_discarded_total')
            .empty,
          a_counter_metric('active_job_duration_seconds')
            .with(5.5, second_job[:labels]),
          a_counter_metric('active_job_latency_seconds')
            .with(1.8, second_job[:labels])
        )
      end
    end
  end
end
