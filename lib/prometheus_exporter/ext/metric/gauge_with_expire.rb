# frozen_string_literal: true

require 'prometheus_exporter/metric'
require_relative '../../ext'

module PrometheusExporter::Ext::Metric
  class GaugeWithExpire < PrometheusExporter::Metric::Gauge
    NULLIFY_STRATEGY_UPDATE = ->(labels) { expiration_times[labels] = now_time + ttl }.freeze
    NULLIFY_STRATEGY_EXPIRE = ->(labels) { data.delete(labels) }.freeze
    ZEROING_STRATEGY_UPDATE = ->(labels) do
      if data[labels].zero?
        expiration_times.delete(labels)
      else
        expiration_times[labels] = now_time + ttl
      end
    end.freeze
    ZEROING_STRATEGY_EXPIRE = ->(labels) { data[labels] = 0 }.freeze

    class << self
      # @return [Hash]
      #   key - strategy name
      #   value [Hash] with keys: :on_update, :on_expire
      #     :on_update [Proc] yieldparam labels [Hash] - updates expiration_times after data was updated (instance exec)
      #     :on_expire [Proc] yieldparam labels [Hash] - updates data after expiration_times was expired (instance exec)
      def strategies
        {
          removing: { on_update: NULLIFY_STRATEGY_UPDATE, on_expire: NULLIFY_STRATEGY_EXPIRE },
          zeroing: { on_update: ZEROING_STRATEGY_UPDATE, on_expire: ZEROING_STRATEGY_EXPIRE }
        }
      end

      def default_ttl
        60
      end
    end

    attr_reader :ttl, :expiration_times

    def initialize(name, help, opts = {})
      super(name, help)
      @ttl = opts[:ttl] || self.class.default_ttl
      raise ArgumentError, ':ttl must be numeric' unless ttl.is_a?(Numeric)
      raise ArgumentError, ":ttl must be greater than zero: #{ttl.inspect}" unless ttl.positive?

      @strategy = self.class.strategies.fetch(opts[:strategy] || :removing) do
        raise ArgumentError, "Unknown strategy: #{opts[:strategy].inspect}"
      end
    end

    def reset!
      @expiration_times = {}
      super
    end

    def metric_text
      expire
      super
    end

    def remove(labels)
      result = super
      remove_expired_at(labels)
      result
    end

    def observe(value, labels = {})
      result = super
      value.nil? ? remove_expired_at(labels) : update_expired_at(labels)
      result
    end

    def increment(labels = {}, value = 1)
      result = super
      update_expired_at(labels)
      result
    end

    def decrement(labels = {}, value = 1)
      result = super
      update_expired_at(labels)
      result
    end

    def expire
      now = now_time
      expiration_times.each do |labels, expired_at|
        if expired_at < now
          remove_data_when_expired(labels)
          remove_expired_at(labels)
        end
      end
    end

    def to_h
      expire
      super
    end

    private

    def remove_data_when_expired(labels)
      instance_exec(labels, &@strategy[:on_expire])
    end

    def update_expired_at(labels)
      instance_exec(labels, &@strategy[:on_update])
    end

    def remove_expired_at(labels)
      expiration_times.delete(labels)
    end

    def now_time
      ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end
  end
end
