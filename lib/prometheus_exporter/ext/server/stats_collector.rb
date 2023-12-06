# frozen_string_literal: true

require_relative 'base_collector_methods'

module PrometheusExporter::Ext::Server
  module StatsCollector
    class << self
      private

      def included(klass)
        super
        klass.include BaseCollectorMethods
        klass.extend ClassMethods
      end
    end

    module ClassMethods
      # Registers PrometheusExporter::Metric::GaugeWithExpire observer.
      # @param name [Symbol] metric name.
      # @param help [String] metric description.
      # @param opts [Hash] additional options, supports `ttl` and `strategy` keys.
      def register_gauge_with_expire(name, help, opts = {})
        register_metric(name, help, PrometheusExporter::Ext::Metric::GaugeWithExpire, opts)
      end
    end

    def initialize
      super
      @observers = build_observers
    end

    # Returns all metrics collected by this collector.
    # @return [Array<PrometheusExporter::Metric::Base>]
    def metrics
      @observers.values
    end

    # Collects metric data received from client.
    # @param obj [Hash] metric data.
    def collect(obj)
      obj = normalize_labels(obj)
      fill_observers(@observers, obj)
    end
  end
end
