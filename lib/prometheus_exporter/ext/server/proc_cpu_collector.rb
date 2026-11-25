# frozen_string_literal: true

require_relative 'stats_collector'

module PrometheusExporter::Ext::Server
  class ProcCpuCollector < PrometheusExporter::Server::TypeCollector
    include ::PrometheusExporter::Ext::Server::StatsCollector
    self.type = 'proc_cpu'

    self.ttl = 300

    register_counter_with_expire :usage_seconds_total, 'Cumulative CPU time consumed by the process in core-seconds'
  end
end
