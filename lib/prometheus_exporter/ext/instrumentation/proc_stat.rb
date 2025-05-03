# frozen_string_literal: true

require_relative 'periodic_stats'
require_relative '../proc_self_stat'

module PrometheusExporter::Ext::Instrumentation
  class ProcStat < PeriodicStats
    self.type = 'proc_stat'

    SLEEP_INTERVAL = 1

    class << self
      def start(frequency: 15, client: PrometheusExporter::Client.default, **)
        raise ArgumentError, 'Expected frequency to be a number' unless frequency.is_a?(Numeric)
        if frequency < SLEEP_INTERVAL
          raise ArgumentError, "Expected frequency to be greater than or equal to #{SLEEP_INTERVAL}"
        end

        super(frequency: frequency - 1, client:, **)
      end
    end

    def collect
      start_time = ::Process.clock_gettime(Process::CLOCK_MONOTONIC)
      start_cpu = PrometheusExporter::Ext::ProcSelfStat.get.cpu_time
      sleep SLEEP_INTERVAL
      end_time = ::Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end_stat = PrometheusExporter::Ext::ProcSelfStat.get
      elapsed_time = end_time - start_time
      cpu_time = end_stat.cpu_time - start_cpu
      cpu_usage = cpu_time / elapsed_time # from 0.0 to 1.0
      collect_data(build_stats(cpu_usage, end_stat))
    end

    private

    def build_stats(cpu_usage, stat)
      {
        labels: { pid: stat.pid, comm: stat.comm },
        cpu_usage:,
        vsize_bytes: stat.vsize,
        rss_bytes: stat.rss_bytes
      }
    end
  end
end
