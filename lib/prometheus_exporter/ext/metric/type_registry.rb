# frozen_string_literal: true

require 'prometheus_exporter/metric'
require_relative 'gauge_with_time'

module PrometheusExporter::Ext::Metric
  module TypeRegistry
    class << self
      attr_accessor :types
    end

    self.types = {}

    module_function

    def register(type, klass)
      types[type.to_s] = klass
    end

    def find_metric_class(type)
      klass = types[type.to_s]
      raise ArgumentError, "Unknown metric type #{type}" unless klass

      klass
    end

    register :gauge_with_time, PrometheusExporter::Ext::Metric::GaugeWithTime
    register :counter, PrometheusExporter::Metric::Counter
    register :gauge, PrometheusExporter::Metric::Gauge
    register :summary, PrometheusExporter::Metric::Summary
    register :histogram, PrometheusExporter::Metric::Histogram
  end
end
