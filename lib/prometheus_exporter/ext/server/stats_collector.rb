# frozen_string_literal: true

require_relative '../metric/type_registry'

module PrometheusExporter::Ext::Server
  module StatsCollector
    class << self
      private

      def included(klass)
        super
        klass.singleton_class.attr_accessor :type, :registered_metrics
        klass.registered_metrics = {}
        klass.extend ClassMethods
        klass.include InstanceMethods
      end
    end

    module ClassMethods
      # rubocop:disable Metrics/ParameterLists
      def register_metric(name, type, help, *args)
        # rubocop:enable Metrics/ParameterLists
        name = name.to_s
        raise ArgumentError, "metric #{name} is already registered" if registered_metrics.key?(name)

        metric_class = PrometheusExporter::Ext::Metric::TypeRegistry.find_metric_class(type)
        registered_metrics[name] = { help:, metric_class:, args: }
      end
    end

    module InstanceMethods
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
end
