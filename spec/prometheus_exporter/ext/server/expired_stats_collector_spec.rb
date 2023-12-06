# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Server::ExpiredStatsCollector do
  describe '#metrics' do
    subject do
      collect_data
      collector.metrics
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
    let(:collect_data) do
      collector.collect(deep_stringify_keys(metric))
    end

    it 'observes prometheus metrics' do
      expect(subject).to contain_exactly(
        a_gauge_metric('test_g_metric').with(1.23, expected_labels),
        a_counter_metric('test_c_metric').with(7.89, expected_labels)
      )
    end

    context 'without data' do
      let(:collect_data) { nil }

      it 'observes empty prometheus metrics' do
        expect(subject).to contain_exactly(
          a_gauge_metric('test_g_metric').empty,
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

      let(:collect_data) do
        collector.collect(deep_stringify_keys(prev_metric))
        sleep(sleep_after_prev_metric)
        super()
      end
      let(:sleep_after_prev_metric) { 0.5 }

      it 'observes prometheus metrics' do
        expect(subject).to contain_exactly(
          a_gauge_metric('test_g_metric').with(1.23, expected_labels),
          a_counter_metric('test_c_metric').with(7.89, expected_labels)
        )
      end

      context 'when previous metrics are expired' do
        let(:sleep_after_prev_metric) { collector.class.ttl + 0.1 }

        it 'observes prometheus metrics' do
          expect(subject).to contain_exactly(
            a_gauge_metric('test_g_metric').with(1.23, expected_labels),
            a_counter_metric('test_c_metric').with(7.89, expected_labels)
          )
        end
      end
    end

    context 'when collector has not expired previous metrics with different labels' do
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
          a_counter_metric('test_c_metric')
            .with(30, prev_expected_labels)
            .with(7.89, expected_labels)
        )
      end

      context 'when previous metrics are expired' do
        let(:sleep_after_prev_metric) { collector.class.ttl + 0.1 }

        it 'observes prometheus metrics' do
          expect(subject).to contain_exactly(
            a_gauge_metric('test_g_metric').with(1.23, expected_labels),
            a_counter_metric('test_c_metric').with(7.89, expected_labels)
          )
        end
      end
    end
  end
end
