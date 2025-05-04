# frozen_string_literal: true

require_relative 'stats_collector'

module PrometheusExporter::Ext::Server
  class ProcCpuCollector < PrometheusExporter::Server::TypeCollector
    include ::PrometheusExporter::Ext::Server::StatsCollector
    self.type = 'proc_cpu'

    register_counter :usage_seconds_total, 'Cumulative CPU time consumed by the process in core-seconds'
  end
end
