# frozen_string_literal: true

require_relative 'periodic_stats'

module PrometheusExporter::Ext::Instrumentation
  # Reports the number of Solid Queue jobs in each execution table.
  # Requires the solid_queue gem to be loaded by the host application.
  # Processed by PrometheusExporter::Ext::Server::SolidQueueCollector.
  class SolidQueue < PeriodicStats
    self.type = 'solid_queue'

    def collect
      safe_collect do
        collect_data(queue_stats)
      end
    end

    private

    def queue_stats
      ::SolidQueue::Record.connection_pool.with_connection do
        {
          ready_count: ::SolidQueue::ReadyExecution.count,
          scheduled_count: ::SolidQueue::ScheduledExecution.count,
          claimed_count: ::SolidQueue::ClaimedExecution.count,
          blocked_count: ::SolidQueue::BlockedExecution.count,
          failed_count: ::SolidQueue::FailedExecution.count
        }
      end
    end
  end
end
