# frozen_string_literal: true

require 'prometheus_exporter/client'

module PrometheusExporter::Ext::Instrumentation
  class BaseStats
    class << self
      attr_accessor :type
    end

    def initialize(client: PrometheusExporter::Client.default, metric_labels: {})
      @metric_labels = metric_labels
      @client = client
    end

    def type
      self.class.type
    end

    def collect
      raise NotImplementedError
    end

    private

    # @param data [Array,Hash]
    def collect_data(data)
      metric = build_metric(data)
      @client.send_json(metric)
    end

    # @param datum [Hash]
    # @return [Hash]
    def build_metric(datum)
      metric = datum.dup
      metric[:type] = type
      metric[:metric_labels] = @metric_labels
      metric
    end
  end
end
