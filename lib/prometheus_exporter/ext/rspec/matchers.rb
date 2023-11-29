# frozen_string_literal: true

require 'date'
require_relative 'metric_matcher'

module PrometheusExporter::Ext::RSpec
  module Matchers
    def a_prometheus_metric(klass, name)
      MetricMatcher.new(klass, name)
    end

    # Matches approximate milliseconds since epoch
    # @param date_time [DateTime] default DateTime.now
    # @param delta [Integer] default 1000 ms
    # @return [RSpec::Matchers::BuiltIn::BeWithin]
    def ms_since_epoch(date_time: DateTime.now, delta: 1_000)
      be_within(delta).of(date_time.strftime('%Q').to_i)
    end

    def a_gauge_metric(name)
      a_prometheus_metric(PrometheusExporter::Metric::Gauge, name)
    end

    def a_gauge_with_time_metric(name)
      a_prometheus_metric(PrometheusExporter::Ext::Metric::GaugeWithTime, name)
    end

    def a_counter_metric(name)
      a_prometheus_metric(PrometheusExporter::Metric::Counter, name)
    end

    def a_histogram_metric(name)
      a_prometheus_metric(PrometheusExporter::Metric::Histogram, name)
    end

    def a_summary_metric(name)
      a_prometheus_metric(PrometheusExporter::Metric::Summary, name)
    end
  end
end
