class PrometheusTestCollector
  attr_reader :collector

  def initialize
    reset
  end

  def metrics
    @collector.prometheus_metrics_text
  end

  def register_collector(collector)
    @collector.register_collector(collector)
  end

  def reset
    @collector = PrometheusExporter::Server::Collector.new
    PrometheusExporter::Client.default = PrometheusExporter::LocalClient.new(collector:)
  end
end
