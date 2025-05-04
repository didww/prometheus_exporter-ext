# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Instrumentation::ProcCpu do
  describe '.start' do
    subject do
      described_class.start(type:, frequency:)
      sleep(wait_seconds)
    end

    let(:type) { 'test' }
    let(:frequency) { 2 }
    # because thread requires few milliseconds to start
    let(:wait_seconds) { 0.1 }
    let(:expected_labels) do
      { type:, pid: Process.pid.to_s, hostname: PrometheusExporter.hostname }
    end

    after do
      described_class.stop
    end

    it 'sends 1 metric' do
      expect { subject }.to send_metrics(
        {
          usage_seconds_total: an_instance_of(Float),
          type: 'proc_cpu',
          labels: expected_labels
        }
      )
    end

    context 'when wait for frequency seconds more' do
      let(:wait_seconds) { super() + frequency } # 2.1

      it 'sends 2 metrics' do
        expect { subject }.to send_metrics(
          {
            usage_seconds_total: an_instance_of(Float),
            type: 'proc_cpu',
            labels: expected_labels
          },
          {
            usage_seconds_total: an_instance_of(Float),
            type: 'proc_cpu',
            labels: expected_labels
          }
        )
      end
    end

    context 'when wait for frequency+1 seconds more' do
      let(:wait_seconds) { super() + frequency + 1 } # 3.1

      it 'sends 2 metrics' do
        expect { subject }.to send_metrics(
          {
            usage_seconds_total: an_instance_of(Float),
            type: 'proc_cpu',
            labels: expected_labels
          },
          {
            usage_seconds_total: an_instance_of(Float),
            type: 'proc_cpu',
            labels: expected_labels
          }
        )
      end
    end
  end
end
