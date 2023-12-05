# frozen_string_literal: true

require 'prometheus_exporter/client'

module PrometheusExporter::Ext::Instrumentation
  class BaseStats
    class << self
      attr_accessor :type
    end

    def initialize(client: PrometheusExporter::Client.default, metric_labels: {})
      @metric_labels = metric_labels.transform_keys(&:to_sym)
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
      data_list = data.is_a?(Array) ? data : [data]
      metrics = data_list.map { |data_item| build_metric(data_item) }
      metrics.map { |metric| @client.send_json(metric) }
    end

    # @param data [Hash]
    # @return [Hash]
    def build_metric(data)
      metric = data.transform_keys(&:to_sym)
      metric[:type] = type
      metric[:labels] ||= {}
      metric[:labels].transform_keys!(&:to_sym)
      metric[:labels].merge!(@metric_labels)
      metric
    end
  end
end
