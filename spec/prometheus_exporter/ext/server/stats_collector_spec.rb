# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Server::StatsCollector do
  subject do
    collector.collect(stringified_metric)
  end

  let(:collector) { TestCollector.new }
  let(:stringified_metric) { JSON.parse JSON.generate(metric) }
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
      a_gauge_with_time_metric('test_gwt_metric').with([4.56, ms_since_epoch], expected_labels),
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
        a_gauge_with_time_metric('test_gwt_metric').with([4.56, ms_since_epoch],
                                                         expected_labels
                                                        ),
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
        a_gauge_with_time_metric('test_gwt_metric').with([4.56, ms_since_epoch], expected_labels),
        a_counter_metric('test_c_metric').with(7.89, expected_labels)
      )
    end
  end

  context 'when collector has previous metrics with same labels' do
    let(:prev_stringified_metric) { JSON.parse JSON.generate(prev_metric) }
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
      collector.collect(prev_stringified_metric)
    end

    it 'observes prometheus metrics' do
      subject
      expect(collector.metrics).to contain_exactly(
        a_gauge_metric('test_g_metric').with(1.23, expected_labels),
        a_gauge_with_time_metric('test_gwt_metric').with([4.56, ms_since_epoch],
                                                         expected_labels
                                                        ),
        a_counter_metric('test_c_metric').with(37.89, expected_labels)
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
        a_gauge_with_time_metric('test_gwt_metric')
          .with([20, ms_since_epoch], prev_expected_labels)
          .with([4.56, ms_since_epoch], expected_labels),
        a_counter_metric('test_c_metric')
          .with(30, prev_expected_labels)
          .with(7.89, expected_labels)
      )
    end
  end
end
