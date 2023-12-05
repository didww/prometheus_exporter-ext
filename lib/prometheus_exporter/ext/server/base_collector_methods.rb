# frozen_string_literal: true

require 'prometheus_exporter/metric'

module PrometheusExporter::Ext::Server
  module BaseCollectorMethods
    class << self
      private

      def included(klass)
        super
        klass.singleton_class.attr_accessor :type, :registered_metrics
        klass.registered_metrics = {}
        klass.extend ClassMethods
      end
    end

    module ClassMethods
      # Registers metric observer.
      # @param name [Symbol] metric name.
      # @param help [String] metric description.
      # @param metric_class [Class<PrometheusExporter::Metric::Base>] observer class.
      # @param args [Array] additional arguments for observer class.
      # rubocop:disable Metrics/ParameterLists
      def register_metric(name, help, metric_class, *args)
        # rubocop:enable Metrics/ParameterLists
        name = name.to_s
        raise ArgumentError, "metric #{name} is already registered" if registered_metrics.key?(name)

        registered_metrics[name] = { help:, metric_class:, args: }
      end

      # Registers PrometheusExporter::Metric::Counter observer.
      # @param name [Symbol] metric name.
      # @param help [String] metric description.
      def register_counter(name, help)
        register_metric(name, help, PrometheusExporter::Metric::Counter)
      end

      # Registers PrometheusExporter::Metric::Gauge observer.
      # @param name [Symbol] metric name.
      # @param help [String] metric description.
      def register_gauge(name, help)
        register_metric(name, help, PrometheusExporter::Metric::Gauge)
      end

      # Registers PrometheusExporter::Metric::Summary observer.
      # @param name [Symbol] metric name.
      # @param help [String] metric description.
      # @param opts [Hash] additional options, supports `quantiles` key.
      def register_summary(name, help, opts = {})
        register_metric(name, help, PrometheusExporter::Metric::Summary, opts)
      end

      # Registers PrometheusExporter::Metric::Histogram observer.
      # @param name [Symbol] metric name.
      # @param help [String] metric description.
      # @param opts [Hash] additional options, supports `buckets` key.
      def register_histogram(name, help, opts = {})
        register_metric(name, help, PrometheusExporter::Metric::Histogram, opts)
      end
    end

    # @return [String]
    def type
      self.class.type
    end

    private

    # Adds metrics to observers with matched name.
    # @param observers [Hash] returned by #build_observers.
    # @param obj [Hash] metric data.
    def fill_observers(observers, obj)
      observers.each do |name, observer|
        value = obj[name]
        observer.observe(value, obj['labels']) if value
      end
    end

    # Generally metrics sent via PrometheusExporter::Ext::Instrumentation::BaseStats populate labels to `labels` key.
    # But PrometheusExporter::Client populate it's own labels to `custom_labels` key.
    # Here we merge them into single `labels` key.
    # @param obj [Hash]
    # @return [Hash]
    def normalize_labels(obj)
      obj['labels'] ||= {}
      custom_labels = obj.delete('custom_labels')
      obj['labels'].merge!(custom_labels) if custom_labels
      obj
    end

    # @return [Hash] key is metric name, value is observer.
    def build_observers
      observers = {}
      self.class.registered_metrics.each do |name, metric|
        observers[name] = metric[:metric_class].new("#{type}_#{name}", metric[:help], *metric[:args])
      end
      observers
    end
  end
end
