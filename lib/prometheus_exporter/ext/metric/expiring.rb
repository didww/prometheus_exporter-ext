# frozen_string_literal: true

require_relative '../../ext'

module PrometheusExporter::Ext::Metric
  # Shared TTL handling for metrics that drop label sets not updated for `ttl` seconds.
  module Expiring
    class << self
      private

      def included(klass)
        super
        klass.extend ClassMethods
      end
    end

    module ClassMethods
      def default_ttl
        60
      end
    end

    attr_reader :ttl, :expiration_times

    private

    def init_ttl(opts)
      @ttl = opts[:ttl] || self.class.default_ttl
      raise ArgumentError, ':ttl must be numeric' unless ttl.is_a?(Numeric)
      raise ArgumentError, ":ttl must be greater than zero: #{ttl.inspect}" unless ttl.positive?
    end

    def now_time
      ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end
  end
end
