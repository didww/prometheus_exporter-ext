# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Server::ProcCpuCollector do
  subject do
    collect_data
    collector.metrics
  end

  let(:collector) { described_class.new }
  let(:metric) do
    {
      labels: { pid: '1234', type: 'test', hostname: 'rspec' },
      usage_seconds_total: 0.123
    }
  end
  let(:expected_labels) { metric[:labels] }
  let(:collect_data) do
    collector.collect(deep_stringify_keys(metric))
  end

  def travel_to_monotonic(seconds)
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(seconds)
  end

  it 'observes prometheus metrics' do
    expect(subject).to contain_exactly(
      a_counter_with_expire_metric('proc_cpu_usage_seconds_total').with(0.123, expected_labels)
    )
  end

  context 'without data' do
    let(:collect_data) { nil }

    it 'observes empty prometheus metrics' do
      expect(subject).to contain_exactly(
        a_counter_with_expire_metric('proc_cpu_usage_seconds_total').empty
      )
    end
  end

  context 'when the process stops reporting' do
    before { travel_to_monotonic(100.0) }

    it 'keeps the series within 300 seconds' do
      collect_data
      travel_to_monotonic(399.0)
      expect(collector.metrics).to contain_exactly(
        a_counter_with_expire_metric('proc_cpu_usage_seconds_total').with(0.123, expected_labels)
      )
    end

    it 'expires the series after 300 seconds' do
      collect_data
      travel_to_monotonic(401.0)
      expect(collector.metrics).to contain_exactly(
        a_counter_with_expire_metric('proc_cpu_usage_seconds_total').empty
      )
    end
  end

  describe '.ttl' do
    around do |example|
      original = described_class.ttl
      example.run
    ensure
      described_class.ttl = original
    end

    it 'defaults to 300' do
      expect(described_class.ttl).to eq(300)
    end

    it 'applies to a new collector instance' do
      described_class.ttl = 10
      expect(collector.metrics.first.ttl).to eq(10)
    end
  end
end
