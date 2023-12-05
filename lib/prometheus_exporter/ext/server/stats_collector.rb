# frozen_string_literal: true

require_relative 'base_collector_methods'

module PrometheusExporter::Ext::Server
  module StatsCollector
    class << self
      private

      def included(klass)
        super
        klass.include BaseCollectorMethods
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
