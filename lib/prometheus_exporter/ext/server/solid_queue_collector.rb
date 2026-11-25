# frozen_string_literal: true

require_relative 'stats_collector'

module PrometheusExporter::Ext::Server
  class SolidQueueCollector < PrometheusExporter::Server::TypeCollector
    include StatsCollector

    self.type = 'solid_queue'

    register_gauge_with_expire :ready_count, 'number of jobs ready to be picked up'
    register_gauge_with_expire :scheduled_count, 'number of jobs scheduled for future execution'
    register_gauge_with_expire :claimed_count, 'number of jobs currently being executed'
    register_gauge_with_expire :blocked_count, 'number of jobs blocked by concurrency controls'
    register_gauge_with_expire :failed_count, 'number of jobs that have failed'
  end
end
