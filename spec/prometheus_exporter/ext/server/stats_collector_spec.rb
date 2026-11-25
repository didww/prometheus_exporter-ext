# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Server::StatsCollector do
  subject do
    collect_data
    collector.metrics
  end

  let(:collector) { TestStatsCollector.new }
  let(:metric) do
    {
      type: 'test',
      labels: { qwe: 'asd' },
      g_metric: 1.23,
      gwen_metric: 1.24,
      gwez_metric: 1.25,
      c_metric: 7.89
    }
  end
  let(:expected_labels) { metric[:labels] }
  let(:collect_data) do
    collector.collect(deep_stringify_keys(metric))
  end

  it 'observes prometheus metrics' do
    expect(subject).to contain_exactly(
      a_gauge_metric('test_g_metric').with(1.23, expected_labels),
      a_gauge_with_expire_metric('test_gwen_metric').with(1.24, expected_labels),
      a_gauge_with_expire_metric('test_gwez_metric').with(1.25, expected_labels),
      a_counter_metric('test_c_metric').with(7.89, expected_labels)
    )
  end

  context 'without data' do
    let(:collect_data) { nil }

    it 'observes empty prometheus metrics' do
      expect(subject).to contain_exactly(
        a_gauge_metric('test_g_metric').empty,
        a_gauge_with_expire_metric('test_gwen_metric').empty,
        a_gauge_with_expire_metric('test_gwez_metric').empty,
        a_counter_metric('test_c_metric').empty
      )
    end
  end

  context 'with empty custom_labels' do
    let(:metric) do
      super().merge custom_labels: {}
    end

    it 'observes prometheus metrics' do
      expect(subject).to contain_exactly(
        a_gauge_metric('test_g_metric').with(1.23, expected_labels),
        a_gauge_with_expire_metric('test_gwen_metric').with(1.24, expected_labels),
        a_gauge_with_expire_metric('test_gwez_metric').with(1.25, expected_labels),
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
      expect(subject).to contain_exactly(
        a_gauge_metric('test_g_metric').with(1.23, expected_labels),
        a_gauge_with_expire_metric('test_gwen_metric').with(1.24, expected_labels),
        a_gauge_with_expire_metric('test_gwez_metric').with(1.25, expected_labels),
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
        gwen_metric: 11,
        gwez_metric: 12,
        c_metric: 20
      }
    end

    let(:collect_data) do
      collector.collect(deep_stringify_keys(prev_metric))
      sleep(sleep_after_prev_metric)
      super()
    end
    let(:sleep_after_prev_metric) { 0.5 }

    it 'observes prometheus metrics' do
      expect(subject).to contain_exactly(
        a_gauge_metric('test_g_metric').with(1.23, expected_labels),
        a_gauge_with_expire_metric('test_gwen_metric').with(1.24, expected_labels),
        a_gauge_with_expire_metric('test_gwez_metric').with(1.25, expected_labels),
        a_counter_metric('test_c_metric').with(27.89, expected_labels) # 20 + 7.89
      )
    end

    context 'when test_gwen_metric prev metric is expired' do
      # test_gwen_metric ttl is 2
      # test_gwez_metric ttl is 3
      let(:sleep_after_prev_metric) { 2.1 }

      it 'observes prometheus metrics' do
        expect(subject).to contain_exactly(
          a_gauge_metric('test_g_metric').with(1.23, expected_labels),
          a_gauge_with_expire_metric('test_gwen_metric').with(1.24, expected_labels),
          a_gauge_with_expire_metric('test_gwez_metric').with(1.25, expected_labels),
          a_counter_metric('test_c_metric').with(27.89, expected_labels) # 20 + 7.89
        )
      end
    end

    context 'when test_gwen_metric and test_gwez_metric prev metrics are expired' do
      # test_gwen_metric ttl is 2
      # test_gwez_metric ttl is 3
      let(:sleep_after_prev_metric) { 3.1 }

      it 'observes prometheus metrics' do
        expect(subject).to contain_exactly(
          a_gauge_metric('test_g_metric').with(1.23, expected_labels),
          a_gauge_with_expire_metric('test_gwen_metric').with(1.24, expected_labels),
          a_gauge_with_expire_metric('test_gwez_metric').with(1.25, expected_labels),
          a_counter_metric('test_c_metric').with(27.89, expected_labels) # 20 + 7.89
        )
      end
    end
  end

  context 'when collector has previous metrics with different labels' do
    let(:prev_metric) do
      {
        type: 'test',
        labels: { qwe: 'asd2' },
        g_metric: 10,
        gwen_metric: 11,
        gwez_metric: 12,
        c_metric: 20
      }
    end
    let(:prev_expected_labels) { prev_metric[:labels] }

    let(:collect_data) do
      collector.collect(deep_stringify_keys(prev_metric))
      sleep(sleep_after_prev_metric)
      super()
    end
    let(:sleep_after_prev_metric) { 0.5 }

    it 'observes prometheus metrics' do
      expect(subject).to contain_exactly(
        a_gauge_metric('test_g_metric')
          .with(10, prev_expected_labels)
          .with(1.23, expected_labels),
        a_gauge_with_expire_metric('test_gwen_metric')
          .with(11, prev_expected_labels)
          .with(1.24, expected_labels),
        a_gauge_with_expire_metric('test_gwez_metric')
          .with(12, prev_expected_labels)
          .with(1.25, expected_labels),
        a_counter_metric('test_c_metric')
          .with(20, prev_expected_labels)
          .with(7.89, expected_labels)
      )
    end

    context 'when test_gwen_metric prev metric is expired' do
      # test_gwen_metric ttl is 2
      # test_gwez_metric ttl is 3
      let(:sleep_after_prev_metric) { 2.1 }

      it 'observes prometheus metrics' do
        expect(subject).to contain_exactly(
          a_gauge_metric('test_g_metric')
            .with(10, prev_expected_labels)
            .with(1.23, expected_labels),
          a_gauge_with_expire_metric('test_gwen_metric')
            .with(1.24, expected_labels), # prev metric deleted
          a_gauge_with_expire_metric('test_gwez_metric')
            .with(12, prev_expected_labels)
            .with(1.25, expected_labels),
          a_counter_metric('test_c_metric')
            .with(20, prev_expected_labels)
            .with(7.89, expected_labels)
        )
      end
    end

    context 'when test_gwen_metric and test_gwez_metric prev metrics are expired' do
      # test_gwen_metric ttl is 2
      # test_gwez_metric ttl is 3
      let(:sleep_after_prev_metric) { 3.1 }

      it 'observes prometheus metrics' do
        expect(subject).to contain_exactly(
          a_gauge_metric('test_g_metric')
            .with(10, prev_expected_labels)
            .with(1.23, expected_labels),
          a_gauge_with_expire_metric('test_gwen_metric')
            .with(1.24, expected_labels), # prev metric deleted
          a_gauge_with_expire_metric('test_gwez_metric')
            .with(0, prev_expected_labels) # prev metric zeroed
            .with(1.25, expected_labels),
          a_counter_metric('test_c_metric')
            .with(20, prev_expected_labels)
            .with(7.89, expected_labels)
        )
      end
    end
  end

  describe '.register_counter_with_expire' do
    let(:collector_class) do
      Class.new(PrometheusExporter::Server::TypeCollector) do
        include PrometheusExporter::Ext::Server::StatsCollector

        self.type = 'cwe'
        register_counter_with_expire :c_metric, 'help', ttl: 5
      end
    end
    let(:collector) { collector_class.new }
    let(:observer) { collector.metrics.first }

    it 'registers a counter with expire using the given ttl' do
      expect(observer).to be_a(PrometheusExporter::Ext::Metric::CounterWithExpire)
      expect(observer.ttl).to eq(5)
    end

    it 'accumulates values' do
      collector.collect(deep_stringify_keys(labels: { qwe: 'asd' }, c_metric: 1.5))
      collector.collect(deep_stringify_keys(labels: { qwe: 'asd' }, c_metric: 2))
      expect(observer.to_h).to eq({ 'qwe' => 'asd' } => 3.5)
    end
  end

  describe '.ttl' do
    let(:collector_class) do
      Class.new(PrometheusExporter::Server::TypeCollector) do
        include PrometheusExporter::Ext::Server::StatsCollector

        self.type = 'ttl'
        self.ttl = 120
        register_gauge_with_expire :gauge, 'help'
        register_counter_with_expire :counter, 'help'
        register_gauge_with_expire :own_ttl_gauge, 'help', ttl: 5
        register_gauge :plain_gauge, 'help'
      end
    end
    let(:observers) { collector_class.new.metrics.to_h { |metric| [metric.name, metric] } }

    it 'applies to expiring metrics registered without ttl' do
      expect(observers.values_at('ttl_gauge', 'ttl_counter').map(&:ttl)).to eq([120, 120])
    end

    it 'keeps a ttl given at registration' do
      expect(observers['ttl_own_ttl_gauge'].ttl).to eq(5)
    end

    it 'builds plain metrics without it' do
      expect(observers['ttl_plain_gauge']).to be_an_instance_of(PrometheusExporter::Metric::Gauge)
    end

    context 'when not set' do
      before { collector_class.ttl = nil }

      it 'keeps the metric default' do
        expect(observers['ttl_gauge'].ttl).to eq(60)
      end
    end
  end
end
