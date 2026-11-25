# frozen_string_literal: true

require_relative 'stats_collector'

module PrometheusExporter::Ext::Server
  class ProcCpuCollector < PrometheusExporter::Server::TypeCollector
    include ::PrometheusExporter::Ext::Server::StatsCollector
    self.type = 'proc_cpu'

    # Seconds a process series is kept without updates. Set it before the collector is instantiated.
    singleton_class.attr_accessor :ttl
    self.ttl = 300

    register_counter_with_expire :usage_seconds_total, 'Cumulative CPU time consumed by the process in core-seconds'

    private

    def build_observers
      self.class.registered_metrics.to_h do |name, metric|
        opts = (metric[:args].first || {}).merge(ttl: self.class.ttl)
        [name, metric[:metric_class].new("#{type}_#{name}", metric[:help], opts)]
      end
    end
  end
end
