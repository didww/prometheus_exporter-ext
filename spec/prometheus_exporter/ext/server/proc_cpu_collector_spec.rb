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

  it 'observes prometheus metrics' do
    expect(subject).to contain_exactly(
      a_counter_metric('proc_cpu_usage_seconds_total').with(0.123, expected_labels)
    )
  end

  context 'without data' do
    let(:collect_data) { nil }

    it 'observes empty prometheus metrics' do
      expect(subject).to contain_exactly(
        a_counter_metric('proc_cpu_usage_seconds_total').empty
      )
    end
  end
end
