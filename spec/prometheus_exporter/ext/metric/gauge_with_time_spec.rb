# frozen_string_literal: true

require 'prometheus_exporter/ext/metric/gauge_with_time'

RSpec.describe PrometheusExporter::Ext::Metric::GaugeWithTime do
  describe '#to_prometheus_text' do
    subject { metric.to_prometheus_text }

    let(:metric) { described_class.new('metric_name', 'help_msg') }

    it 'returns correct text' do
      expect(subject).to eq("# HELP metric_name help_msg\n# TYPE metric_name gauge\n\n")
    end

    context 'with metric_text' do
      let(:metric_text) { "metric_text 1\nmetric_text 2" }

      before { allow(metric).to receive(:metric_text).once.and_return(metric_text) }

      it 'returns correct text' do
        title = "# HELP metric_name help_msg\n# TYPE metric_name gauge"
        expect(subject).to eq("#{title}\n#{metric_text}\n")
      end
    end
  end

  describe '#metric_text' do
    subject { metric.metric_text.split("\n") }

    let(:metric) { described_class.new('metric_name', 'help_msg') }

    it 'returns correct text' do
      expect(subject).to eq([])
    end

    it 'has correct to_h' do
      expect(metric.to_h).to eq({})
    end

    context 'when metric has data with stubbed timestamps' do
      let!(:date_time_old) { DateTime.now - 25 }
      let!(:date_time_new) { DateTime.now }

      before do
        allow(DateTime).to receive(:now).once.and_return(date_time_old)
        metric.observe(1, 'foo' => 'bar')

        allow(DateTime).to receive(:now).once.and_return(date_time_new)
        metric.observe(2, 'baz' => 'boo')
      end

      it 'returns correct text' do
        expect(subject).to contain_exactly(
          %(metric_name{foo="bar"} 1 #{date_time_old.strftime('%Q').to_i}),
          %(metric_name{baz="boo"} 2 #{date_time_new.strftime('%Q').to_i})
        )
      end

      it 'has correct to_h' do
        expect(metric.to_h).to match(
          {
            { 'foo' => 'bar' } => [1, date_time_old.strftime('%Q').to_i],
            { 'baz' => 'boo' } => [2, date_time_new.strftime('%Q').to_i]
          }
        )
      end

      it 'matches a_gauge_with_time_metric' do
        expect(metric).to a_gauge_with_time_metric('metric_name')
          .with([1, date_time_old.strftime('%Q').to_i], foo: 'bar')
          .with([2, date_time_new.strftime('%Q').to_i], baz: 'boo')
      end
    end

    context 'when metric has data without stubbed timestamps' do
      before do
        metric.observe(1, 'foo' => 'bar')
        sleep 0.2
        metric.observe(2, baz: 'boo')
      end

      it 'has correct to_h' do
        expect(metric.to_h).to match(
          {
            { 'foo' => 'bar' } => [1, ms_since_epoch],
            { baz: 'boo' } => [2, ms_since_epoch]
          }
        )
      end

      it 'matches a_gauge_with_time_metric' do
        expect(metric).to a_gauge_with_time_metric('metric_name')
          .with([1, ms_since_epoch], foo: 'bar')
          .with([2, ms_since_epoch], baz: 'boo')
      end
    end
  end
end
