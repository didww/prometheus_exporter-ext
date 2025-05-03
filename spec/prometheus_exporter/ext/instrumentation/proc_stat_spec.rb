# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Instrumentation::ProcStat do
  describe '.start' do
    subject do
      described_class.start(frequency:)
      sleep(wait_seconds)
    end

    let(:frequency) { 2 }
    # SLEEP_INTERVAL it how much time instrumentation gather stats,
    # 0.1 because thread requires few milliseconds to start
    let(:wait_seconds) { PrometheusExporter::Ext::Instrumentation::ProcStat::SLEEP_INTERVAL + 0.1 }

    after do
      described_class.stop
    end

    it 'sends 1 metric' do
      expect { subject }.to send_metrics(
        {
          cpu_usage: an_instance_of(Float).and(be_between(0.0, 1.0)),
          rss_bytes: an_instance_of(Integer).and(be >= 4096),
          vsize_bytes: an_instance_of(Integer).and(be > 0),
          type: 'proc_stat',
          labels: { comm: 'ruby', pid: Process.pid.to_s }
        }
      )
    end

    context 'when wait for frequency seconds more' do
      let(:wait_seconds) { super() + frequency } # 3.1

      it 'sends 2 metrics' do
        expect { subject }.to send_metrics(
          {
            cpu_usage: an_instance_of(Float),
            rss_bytes: an_instance_of(Integer),
            vsize_bytes: an_instance_of(Integer),
            type: 'proc_stat',
            labels: { comm: 'ruby', pid: Process.pid.to_s }
          },
          {
            cpu_usage: an_instance_of(Float),
            rss_bytes: an_instance_of(Integer),
            vsize_bytes: an_instance_of(Integer),
            type: 'proc_stat',
            labels: { comm: 'ruby', pid: Process.pid.to_s }
          }
        ).ordered
      end
    end

    context 'when wait for frequency+1 seconds more' do
      let(:wait_seconds) { super() + frequency + 1 } # 3.1

      it 'sends 2 metrics' do
        expect { subject }.to send_metrics(
          {
            cpu_usage: an_instance_of(Float),
            rss_bytes: an_instance_of(Integer),
            vsize_bytes: an_instance_of(Integer),
            type: 'proc_stat',
            labels: { comm: 'ruby', pid: Process.pid.to_s }
          },
          {
            cpu_usage: an_instance_of(Float),
            rss_bytes: an_instance_of(Integer),
            vsize_bytes: an_instance_of(Integer),
            type: 'proc_stat',
            labels: { comm: 'ruby', pid: Process.pid.to_s }
          }
        ).ordered
      end
    end
  end
end
