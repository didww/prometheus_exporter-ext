# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Server::ExpiredStatsCollector do
  subject do
    collector.collect(deep_stringify_keys(metric))
  end

  let(:collector) { TestExpiredCollector.new }
  let(:metric) do
    {
      type: 'test',
      labels: { qwe: 'asd' },
      g_metric: 1.23,
      gwt_metric: 4.56,
      c_metric: 7.89
    }
  end
  let(:expected_labels) { metric[:labels] }

  it 'observes prometheus metrics' do
    subject
    expect(collector.metrics).to contain_exactly(
      a_gauge_metric('test_g_metric').with(1.23, expected_labels),
      a_counter_metric('test_c_metric').with(7.89, expected_labels)
    )
  end

  context 'with empty custom_labels' do
    let(:metric) do
      super().merge custom_labels: {}
    end

    it 'observes prometheus metrics' do
      subject
      expect(collector.metrics).to contain_exactly(
        a_gauge_metric('test_g_metric').with(1.23, expected_labels),
        a_counter_metric('test_c_metric').with(7.89, expected_labels)
      )
    end
  end

  context 'with filled custom_labels' do
    let(:metric) do
      super().merge custom_labels: { host: 'example.com' }
    end
    let(:expected_labels) { metric[:labels].merge metric[:custom_labels] }

    it 'observes prometheus metrics' do
      subject
      expect(collector.metrics).to contain_exactly(
        a_gauge_metric('test_g_metric').with(1.23, expected_labels),
        a_counter_metric('test_c_metric').with(7.89, expected_labels)
      )
    end
  end

  context 'when collector has previous metrics with same labels' do
    let(:prev_metric) do
      {
        type: 'test',
        labels: { qwe: 'asd' },
        g_metric: 10,
        gwt_metric: 20,
        c_metric: 30
      }
    end

    before do
      collector.collect(deep_stringify_keys(prev_metric))
    end

    it 'observes prometheus metrics' do
      subject
      expect(collector.metrics).to contain_exactly(
        a_gauge_metric('test_g_metric').with(1.23, expected_labels),
        a_counter_metric('test_c_metric').with(7.89, expected_labels) # was replaced, not incremented
      )
    end
  end

  context 'when collector has previous metrics with different labels' do
    let(:prev_stringified_metric) { JSON.parse JSON.generate(prev_metric) }
    let(:prev_metric) do
      {
        type: 'test',
        labels: { qwe: 'asd2' },
        g_metric: 10,
        gwt_metric: 20,
        c_metric: 30
      }
    end
    let(:prev_expected_labels) { prev_metric[:labels] }

    before do
      collector.collect(prev_stringified_metric)
    end

    it 'observes prometheus metrics' do
      subject
      expect(collector.metrics).to contain_exactly(
        a_gauge_metric('test_g_metric')
          .with(10, prev_expected_labels)
          .with(1.23, expected_labels),
        a_counter_metric('test_c_metric')
          .with(30, prev_expected_labels)
          .with(7.89, expected_labels)
      )
    end

    context 'when previous metrics are expired' do
      before do
        sleep_seconds = collector.class.ttl + 0.1
        sleep(sleep_seconds)
      end

      it 'observes prometheus metrics' do
        subject
        expect(collector.metrics).to contain_exactly(
          a_gauge_metric('test_g_metric').with(1.23, expected_labels),
          a_counter_metric('test_c_metric').with(7.89, expected_labels)
        )
      end
    end
  end
end
