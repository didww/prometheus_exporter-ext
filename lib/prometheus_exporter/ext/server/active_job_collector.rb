# frozen_string_literal: true

require_relative 'stats_collector'

module PrometheusExporter::Ext::Server
  class ActiveJobCollector < PrometheusExporter::Server::TypeCollector
    include StatsCollector

    self.type = 'active_job'

    register_counter :enqueued_total, 'total enqueued jobs qty'
    register_counter :fail_enqueued_total, 'total jobs qty that were failed to enqueue'
    register_counter :executed_total, 'total executed jobs qty'
    register_counter :failed_total, 'total jobs qty that failed, without successful retry, rescue, or discard'
    register_counter :success_total,
                     'total successfully executed jobs qty, including with successful retry, rescue, or discard'
    register_counter :retried_total, 'total successfully retried jobs qty'
    register_counter :retry_stopped_total, 'total failed retry jobs qty, due to max attempts reached'
    register_counter :discarded_total, 'total discarded jobs qty'
    register_counter :duration_seconds, 'seconds qty of job execution'
    register_counter :latency_seconds, 'seconds qty from enqueuing to start performing a job'
  end
end
