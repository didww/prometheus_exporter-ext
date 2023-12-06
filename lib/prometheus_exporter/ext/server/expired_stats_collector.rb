# frozen_string_literal: true

require_relative 'base_collector_methods'
require 'prometheus_exporter/server/metrics_container'

module PrometheusExporter::Ext::Server
  module ExpiredStatsCollector
    class << self
      private

      def included(klass)
        super
        klass.include BaseCollectorMethods
        klass.singleton_class.attr_accessor :filter, :ttl
        klass.ttl = 60
        klass.extend ClassMethods
      end
    end

    module ClassMethods
      # Defines a rule how old metric will be replaced with new one.
      # @yield compare new metric with existing one.
      # @yieldparam new_metric [Hash] new metric data.
      # @yieldparam old_metric [Hash] existing metric data.
      # @yieldreturn [Boolean] if true existing metric will be replaced with new one.
      def unique_metric_by(&block)
        @filter = block
      end
    end

    def initialize
      super
      @data = PrometheusExporter::Server::MetricsContainer.new(
        ttl: self.class.ttl,
        filter: self.class.filter
      )
    end

    # Returns all metrics collected by this collector.
    # @return [Array<PrometheusExporter::Metric::Base>]
    def metrics
      observers = build_observers
      @data.each do |obj|
        fill_observers(observers, obj)
      end

      observers.values
    end

    # Collects metric data received from client.
    # @param obj [Hash] metric data.
    def collect(obj)
      normalize_labels(obj)
      @data << obj
    end
  end
end
