# frozen_string_literal: true

require 'prometheus_exporter'
require 'prometheus_exporter/server'
require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/rspec'
require 'prometheus_exporter/ext/instrumentation/base_stats'
require 'prometheus_exporter/ext/server/stats_collector'

RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = nil

class TestInstrumentation < PrometheusExporter::Ext::Instrumentation::BaseStats
  self.type = 'test'

  def collect(data_list)
    data_list.each do |data|
      collect_data(data)
    end
  end
end

class TestCollector < PrometheusExporter::Server::TypeCollector
  include PrometheusExporter::Ext::Server::StatsCollector
  self.type = 'test'

  register_metric :g_metric, :gauge, 'test gauge metric'
  register_metric :gwt_metric, :gauge_with_time, 'test gauge with time metric'
  register_metric :c_metric, :counter, 'test counter metric'
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
