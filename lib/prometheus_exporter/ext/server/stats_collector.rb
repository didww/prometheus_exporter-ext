# frozen_string_literal: true

require 'prometheus_exporter/server/type_collector'
require 'prometheus_exporter/ext/metric/gauge_with_time'

module PrometheusExporter::Ext::Server
  class StatsCollector < PrometheusExporter::Server::TypeCollector
    class << self
      attr_accessor :type, :registered_metrics

      # rubocop:disable Metrics/ParameterLists
      def register_metric(name, type, help, *args)
        # rubocop:enable Metrics/ParameterLists
        name = name.to_s
        raise ArgumentError, "metric #{name} is already registered" if registered_metrics.key?(name)

        metric_class = find_metric_class(type)
        registered_metrics[name] = { help:, metric_class:, args: }
      end

      def find_metric_class(type)
        case type
        when :gauge_with_time
          PrometheusExporter::Ext::Metric::GaugeWithTime
        when :counter
          PrometheusExporter::Metric::Counter
        when :gauge
          PrometheusExporter::Metric::Gauge
        when :summary
          PrometheusExporter::Metric::Summary
        when :histogram
          PrometheusExporter::Metric::Histogram
        else
          raise ArgumentError, "Unknown metric type #{type}"
        end
      end

      private

      def inherited(subclass)
        super
        subclass.registered_metrics = {}
      end
    end

    def initialize
      super
      build_observers
    end

    def type
      self.class.type
    end

    def metrics
      @observers.values
    end

    def collect(obj)
      labels = build_labels(obj)
      fill_observers(obj, labels)
    end

    private

    def fill_observers(obj, labels)
      @observers.each do |name, observer|
        value = obj[name]
        observer.observe(value, labels) if value
      end
    end

    def build_labels(obj)
      labels = {}
      labels.merge!(obj['labels']) if obj['labels']
      labels.merge!(obj['metric_labels']) if obj['metric_labels']

      labels
    end

    def build_observers
      @observers = self.class.registered_metrics.to_h do |name, metric|
        observer = metric[:metric_class].new("#{type}_#{name}", metric[:help], *metric[:args])
        [name, observer]
      end
    end
  end
end
