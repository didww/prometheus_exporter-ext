# frozen_string_literal: true

module PrometheusExporter::Ext::RSpec
  class SendMetricsMatcher
    include RSpec::Matchers::DSL::DefaultImplementations
    include RSpec::Matchers
    include RSpec::Matchers::Composable

    attr_reader :expected, :actual

    def initialize(expected)
      @expected = expected&.map { |metric| deep_stringify_keys(metric) }
      @ordered = false
      @times = nil
    end

    def name
      'sends metrics to prometheus'
    end

    def supports_block_expectations?
      true
    end

    def matches?(actual_proc)
      raise ArgumentError, "#{name} matcher supports only block expectations" unless actual_proc.is_a?(Proc)

      metrics_before = PrometheusExporter::Ext::RSpec::TestClient.instance.metrics
      actual_proc.call
      metrics_after = PrometheusExporter::Ext::RSpec::TestClient.instance.metrics - metrics_before
      @actual = metrics_after.map { |metric| deep_stringify_keys(metric) }

      if expected
        expected_value = @ordered ? expected : match_array(expected)
        values_match?(expected_value, actual)
      elsif @qty
        values_match?(@qty, actual.size)
      else
        actual.size >= 1
      end
    end

    def failure_message
      if expected
        expected_value = @ordered ? expected : match_array(expected)
        +"expected #{name} to receive #{description_of(expected_value)}, but got\n    #{description_of(actual)}"
      elsif @times
        values_match?(@times, actual.size)
        +"expected #{name} to receive #{@times} metrics, but got #{actual.size}\n    #{description_of(actual)}"
      else
        actual.size
        +"expected #{name} to receive more than 1 metric, but got #{actual.size}\n    #{description_of(actual)}"
      end
    end

    def ordered
      raise ArgumentError, 'ordered cannot be when expected not provided' if expected.nil?
      raise ArgumentError, 'ordered cannot be used with times' if @times

      @ordered = true
      self
    end

    def times(qty)
      raise ArgumentError, 'times argument must be an integer' unless qty.is_a?(Integer)
      raise ArgumentError, 'times argument must be >= 1' unless qty >= 1
      raise ArgumentError, 'ordered cannot be when expected is provided' unless expected.nil?
      raise ArgumentError, 'ordered cannot be used with times' if @ordered

      @times = qty
      self
    end

    def description_of(object)
      RSpec::Support::ObjectFormatter.new(nil).format(object)
    end

    private

    def deep_stringify_keys(hash)
      JSON.parse JSON.generate(hash)
    end
  end
end
