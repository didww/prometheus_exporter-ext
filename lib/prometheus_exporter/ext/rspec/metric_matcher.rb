# frozen_string_literal: true

module PrometheusExporter::Ext::RSpec
  class MetricMatcher
    include RSpec::Matchers::DSL::DefaultImplementations
    include RSpec::Matchers
    include RSpec::Matchers::Composable

    attr_reader :metric_class, :metric_name, :metric_payload, :actual

    def initialize(metric_class, metric_name)
      @metric_class = metric_class
      @metric_name = metric_name.to_s
      @metric_payload = nil
    end

    def name
      'be a prometheus metric'
    end

    def expected
      "#{metric_class}(name=#{metric_name}, to_h=#{description_of(metric_payload)})"
    end

    def matches?(actual)
      @actual = actual

      return false unless values_match?(metric_class, actual.class)
      return false unless values_match?(metric_name, actual.name.to_s)

      actual_payload = actual.to_h.transform_keys { |labels| labels.transform_keys(&:to_s) }
      return false if !metric_payload.nil? && !values_match?(metric_payload, actual_payload)

      true
    end

    def with(value, labels)
      @metric_payload ||= {}
      metric_payload[labels.transform_keys(&:to_s)] = value
      self
    end

    def empty
      @metric_payload = {}
      self
    end

    def description_of(object)
      RSpec::Support::ObjectFormatter.new(nil).format(object)
    end
  end
end
