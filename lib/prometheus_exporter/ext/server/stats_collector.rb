# frozen_string_literal: true

require_relative 'base_collector_methods'
require_relative '../metric/counter_with_expire'

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
      # Seconds an expiring metric keeps a label set without updates, for metrics registered without `ttl:`.
      # nil keeps each metric's default. Set it before the collector is instantiated.
      attr_accessor :ttl

      # Registers PrometheusExporter::Metric::GaugeWithExpire observer.
      # @param name [Symbol] metric name.
      # @param help [String] metric description.
      # @param opts [Hash] additional options, supports `ttl` and `strategy` keys.
      def register_gauge_with_expire(name, help, opts = {})
        register_metric(name, help, PrometheusExporter::Ext::Metric::GaugeWithExpire, opts)
      end

      # Registers PrometheusExporter::Ext::Metric::CounterWithExpire observer.
      # @param name [Symbol] metric name.
      # @param help [String] metric description.
      # @param opts [Hash] additional options, supports `ttl` key.
      def register_counter_with_expire(name, help, opts = {})
        register_metric(name, help, PrometheusExporter::Ext::Metric::CounterWithExpire, opts)
      end
    end

    def initialize
      super
      @observers = build_stats_observers
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

    private

    # BaseCollectorMethods#build_observers ignores the collector ttl.
    def build_stats_observers
      self.class.registered_metrics.to_h do |name, metric|
        args = metric[:args]
        if self.class.ttl && metric[:metric_class] < PrometheusExporter::Ext::Metric::Expiring
          args = [{ ttl: self.class.ttl }.merge(args.first || {})]
        end
        [name, metric[:metric_class].new("#{type}_#{name}", metric[:help], *args)]
      end
    end
  end
end
