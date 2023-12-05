# frozen_string_literal: true

require_relative 'base_stats'

module PrometheusExporter::Ext::Instrumentation
  class PeriodicStats < BaseStats
    class << self
      def start(frequency: 30, client: PrometheusExporter::Client.default, **)
        raise ArgumentError, 'Expected frequency to be a number' unless frequency.is_a?(Numeric)
        raise ArgumentError, 'Expected frequency to be a positive number' if frequency.negative?

        klass = self
        stop
        instrumentation = new(client:, **)
        @stop_thread = false

        @thread = Thread.new do
          until @stop_thread
            begin
              instrumentation.collect
            rescue StandardError => e
              client.logger.error("#{klass} Prometheus Exporter Failed To Collect Stats")
              client.logger.error("#{e.class} #{e.backtrace&.join("\n")}")
            ensure
              sleep frequency
            end
          end
        end
      end

      def started?
        !!@thread&.alive?
      end

      def stop
        # to avoid a warning
        @thread = nil unless defined?(@thread)

        if @thread&.alive?
          @stop_thread = true
          @thread.wakeup
          @thread.join
        end
        @thread = nil
      end
    end
  end
end
