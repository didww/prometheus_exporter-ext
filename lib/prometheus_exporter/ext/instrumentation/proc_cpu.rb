# frozen_string_literal: true

require_relative 'periodic_stats'
require_relative '../proc_self_stat'

module PrometheusExporter::Ext::Instrumentation
  class ProcCpu < PeriodicStats
    self.type = 'proc_cpu'

    class << self
      def start(type:, labels: {}, **)
        labels = labels.merge(type:)

        super(labels:, **)
      end
    end

    def initialize(...)
      @last_cpu_time = 0.0
      super
    end

    def collect
      stat = PrometheusExporter::Ext::ProcSelfStat.get
      collect_data(
        labels: { pid: stat.pid },
        usage_seconds_total: stat.cpu_time - @last_cpu_time
      )
      @last_cpu_time = stat.cpu_time
    end
  end
end
