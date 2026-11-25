# frozen_string_literal: true

require 'prometheus_exporter/client'
require_relative '../../ext'

module PrometheusExporter::Ext::Instrumentation
  class BaseStats
    class << self
      attr_accessor :type
    end

    # @param on_error [#call, nil] receives the exception raised inside #safe_collect.
    #   Defaults to printing a warning. If the handler raises, both errors are printed as warnings.
    def initialize(client: PrometheusExporter::Client.default, labels: {}, on_error: nil)
      @labels = labels.transform_keys(&:to_sym)
      @client = client
      @on_error = on_error || method(:warn_error)
    end

    def type
      self.class.type
    end

    def collect
      raise NotImplementedError
    end

    private

    # Runs the block and passes any StandardError to the on_error handler instead of raising it.
    def safe_collect
      yield
    rescue StandardError => e
      report_error(e)
      nil
    end

    # ActiveSupport::Notifications re-raises subscriber errors into the app, so a failing handler must not raise.
    def report_error(error)
      @on_error.call(error)
    rescue StandardError => e
      warn_error(error)
      warn_error(e)
    end

    def warn_error(error)
      warn "Failed to send metrics Prometheus #{self.class.name}: #{error.class}: #{error.message}"
    end

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
      metric[:labels].merge!(@labels)
      metric
    end
  end
end
