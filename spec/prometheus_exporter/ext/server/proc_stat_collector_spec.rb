# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Server::ProcStatCollector do
  subject do
    collect_data
    collector.metrics
  end

  let(:collector) { described_class.new }
  let(:metric) do
    {
      labels: { pid: '1234', comm: 'ruby' },
      cpu_usage: 0.123,
      vsize_bytes: 123_456_789,
      rss_bytes: 123_456
    }
  end
  let(:expected_labels) { metric[:labels] }
  let(:collect_data) do
    collector.collect(deep_stringify_keys(metric))
  end

  it 'observes prometheus metrics' do
    expect(subject).to contain_exactly(
      a_gauge_with_expire_metric('proc_stat_cpu_usage').with(0.123, expected_labels),
      a_gauge_with_expire_metric('proc_stat_vsize_bytes').with(123_456_789, expected_labels),
      a_gauge_with_expire_metric('proc_stat_rss_bytes').with(123_456, expected_labels)
    )
  end

  context 'without data' do
    let(:collect_data) { nil }

    it 'observes empty prometheus metrics' do
      expect(subject).to contain_exactly(
        a_gauge_with_expire_metric('proc_stat_cpu_usage').empty,
        a_gauge_with_expire_metric('proc_stat_vsize_bytes').empty,
        a_gauge_with_expire_metric('proc_stat_rss_bytes').empty
      )
    end
  end
end
