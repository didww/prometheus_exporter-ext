# frozen_string_literal: true

require 'prometheus_exporter/metric'
require_relative '../../ext'
require_relative 'expiring'

module PrometheusExporter::Ext::Metric
  # Counter that drops a label set not updated for `ttl` seconds. Same removing strategy as GaugeWithExpire.
  class CounterWithExpire < PrometheusExporter::Metric::Counter
    include Expiring

    def initialize(name, help, opts = {})
      super(name, help)
      init_ttl(opts)
    end

    def reset!
      @expiration_times = {}
      super
    end

    def metric_text
      expire
      super
    end

    def to_h
      expire
      super
    end

    def remove(labels)
      expiration_times.delete(labels)
      super
    end

    def observe(increment = 1, labels = {}) = with_expiry(labels) { super }

    def increment(labels = {}, value = 1) = with_expiry(labels) { super }

    def decrement(labels = {}, value = 1) = with_expiry(labels) { super }

    def reset(labels = {}, value = 0) = with_expiry(labels) { super }

    def expire
      now = now_time
      expiration_times.delete_if do |labels, expired_at|
        next false if expired_at >= now

        data.delete(labels)
        true
      end
    end

    private

    # A series that expired but was not read yet must restart from zero.
    def with_expiry(labels)
      drop_if_stale(labels)
      result = yield
      expiration_times[labels] = now_time + ttl
      result
    end

    def drop_if_stale(labels)
      expired_at = expiration_times[labels]
      return if expired_at.nil? || expired_at >= now_time

      data.delete(labels)
      expiration_times.delete(labels)
    end
  end
end
