# frozen_string_literal: true

require 'prometheus_exporter/ext/server/solid_queue_collector'

RSpec.describe PrometheusExporter::Ext::Server::SolidQueueCollector do
  subject do
    collect_data
    collector.metrics
  end

  let(:collector) { described_class.new }
  let(:metric) do
    {
      type: 'solid_queue',
      ready_count: 10,
      scheduled_count: 3,
      claimed_count: 2,
      blocked_count: 1,
      failed_count: 0,
      labels: {}
    }
  end
  let(:expected_labels) { metric[:labels] }
  let(:collect_data) do
    collector.collect(deep_stringify_keys(metric))
  end

  it 'handles the solid_queue type' do
    expect(collector.type).to eq('solid_queue')
  end

  it 'observes prometheus metrics' do
    expect(subject).to contain_exactly(
      a_gauge_with_expire_metric('solid_queue_ready_count').with(10, expected_labels),
      a_gauge_with_expire_metric('solid_queue_scheduled_count').with(3, expected_labels),
      a_gauge_with_expire_metric('solid_queue_claimed_count').with(2, expected_labels),
      a_gauge_with_expire_metric('solid_queue_blocked_count').with(1, expected_labels),
      a_gauge_with_expire_metric('solid_queue_failed_count').with(0, expected_labels)
    )
  end

  context 'without data' do
    let(:collect_data) { nil }

    it 'observes empty prometheus metrics' do
      expect(subject.size).to eq(5)
      expect(subject).to all(be_a(PrometheusExporter::Ext::Metric::GaugeWithExpire))
      expect(subject.map(&:to_h)).to all(be_empty)
    end
  end

  context 'with custom_labels' do
    let(:metric) { super().merge(custom_labels: { env: 'test' }) }
    let(:expected_labels) { { env: 'test' } }

    it 'merges custom_labels into the series labels' do
      expect(subject).to include(
        a_gauge_with_expire_metric('solid_queue_ready_count').with(10, expected_labels)
      )
    end
  end

  context 'when series were not refreshed within the ttl' do
    before do
      collect_data
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(Float::INFINITY)
    end

    it 'expires them' do
      expect(subject.map(&:to_h)).to all(be_empty)
    end
  end

  context 'with an unknown key in payload' do
    let(:metric) { super().merge(unknown_key: 99) }

    it 'ignores it' do
      expect { subject }.not_to raise_error
      expect(subject.size).to eq(5)
    end
  end
end
