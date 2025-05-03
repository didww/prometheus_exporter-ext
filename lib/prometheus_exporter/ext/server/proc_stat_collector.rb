# frozen_string_literal: true

require_relative 'stats_collector'

module PrometheusExporter::Ext::Server
  class ProcStatCollector < PrometheusExporter::Server::TypeCollector
    include ::PrometheusExporter::Ext::Server::StatsCollector
    self.type = 'proc_stat'

    register_gauge_with_expire :cpu_usage, 'new events qty for queue', strategy: :removing, ttl: 30
    register_gauge_with_expire :vsize_bytes, 'Virtual memory size in bytes', strategy: :removing, ttl: 30
    register_gauge_with_expire :rss_bytes, 'Resident Set Size in bytes', strategy: :removing, ttl: 30
  end
end
