# frozen_string_literal: true

require 'date'
require_relative 'metric_matcher'
require_relative 'send_metrics_matcher'

module PrometheusExporter::Ext::RSpec
  module Matchers
    def send_metrics(*expected)
      expected = nil if expected.empty?
      PrometheusExporter::Ext::RSpec::SendMetricsMatcher.new(expected)
    end

    def a_prometheus_metric(klass, name)
      MetricMatcher.new(klass, name)
    end

    def a_gauge_metric(name)
      a_prometheus_metric(PrometheusExporter::Metric::Gauge, name)
    end

    def a_gauge_with_expire_metric(name)
      a_prometheus_metric(PrometheusExporter::Ext::Metric::GaugeWithExpire, name)
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
