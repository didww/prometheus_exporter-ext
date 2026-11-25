# frozen_string_literal: true

require 'prometheus_exporter/ext/instrumentation/solid_queue'

RSpec.describe PrometheusExporter::Ext::Instrumentation::SolidQueue do
  subject(:instrumentation) { described_class.new(**options) }

  let(:options) { {} }
  let(:pool) { double(:connection_pool) }
  let(:ready_execution) { double(:ready_execution, count: 3) }

  before do
    allow(pool).to receive(:with_connection).and_yield
    stub_const('SolidQueue::Record', double(:record, connection_pool: pool))
    stub_const('SolidQueue::ReadyExecution', ready_execution)
    stub_const('SolidQueue::ScheduledExecution', double(:scheduled_execution, count: 5))
    stub_const('SolidQueue::ClaimedExecution', double(:claimed_execution, count: 2))
    stub_const('SolidQueue::BlockedExecution', double(:blocked_execution, count: 1))
    stub_const('SolidQueue::FailedExecution', double(:failed_execution, count: 4))
  end

  it 'handles the solid_queue type' do
    expect(described_class.type).to eq('solid_queue')
  end

  describe '#collect' do
    subject { instrumentation.collect }

    it 'sends current queue counts' do
      expect { subject }.to send_metrics(
        {
          type: 'solid_queue',
          ready_count: 3,
          scheduled_count: 5,
          claimed_count: 2,
          blocked_count: 1,
          failed_count: 4,
          labels: {}
        }
      )
    end

    it 'counts inside a pooled connection' do
      subject
      expect(pool).to have_received(:with_connection).once
    end

    context 'with custom labels' do
      let(:options) { { labels: { env: 'test' } } }

      it 'sends the labels' do
        expect { subject }.to send_metrics(hash_including(type: 'solid_queue', labels: { env: 'test' }))
      end
    end

    context 'when a count raises' do
      before do
        allow(ready_execution).to receive(:count).and_raise(StandardError, 'DB error')
      end

      it 'does not raise and sends nothing' do
        expect { expect { subject }.not_to send_metrics }.to output.to_stderr
      end

      it 'warns by default' do
        expect { subject }.to output(/SolidQueue: StandardError: DB error/).to_stderr
      end

      context 'with on_error handler' do
        let(:options) { { on_error: ->(error) { errors << error } } }
        let(:errors) { [] }

        it 'passes the error to the handler' do
          expect { subject }.not_to output.to_stderr
          expect(errors).to contain_exactly(an_instance_of(StandardError))
        end
      end
    end
  end

  describe '.start' do
    before do
      allow(ready_execution).to receive(:count).and_raise(StandardError, 'DB error')
    end

    after do
      described_class.stop
    end

    it 'forwards on_error to the instrumentation' do
      errors = Queue.new
      described_class.start(frequency: 60, on_error: ->(error) { errors << error })
      expect(errors.pop(timeout: 2)).to be_an_instance_of(StandardError)
    end
  end
end
