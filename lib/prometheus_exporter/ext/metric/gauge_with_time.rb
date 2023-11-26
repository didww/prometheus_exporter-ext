# frozen_string_literal: true

require 'prometheus_exporter/metric'

module PrometheusExporter::Ext::Metric
  class GaugeWithTime < Gauge
    attr_reader :timestamps

    def reset!
      @data = {}
      @timestamps = {}
    end

    def metric_text
      @data.map do |labels, value|
        "#{prefix(@name)}#{labels_text(labels)} #{value} #{timestamps[labels]}"
      end.join("\n")
    end

    def remove(labels)
      result = super
      remove_timestamp(labels)
      result
    end

    def observe(value, labels = {})
      result = super
      value.nil? ? remove_timestamp(labels) : update_timestamp(labels)
      result
    end

    def increment(labels = {}, value = 1)
      result = super
      update_timestamp(labels)
      result
    end

    def decrement(labels = {}, value = 1)
      result = super
      update_timestamp(labels)
      result
    end

    private

    def update_timestamp(labels)
      timestamps[labels] = DateTime.now.strftime('%Q').to_i
    end

    def remove_timestamp(labels)
      timestamps.delete(labels)
    end
  end
end
