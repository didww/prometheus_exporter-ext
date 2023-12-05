# frozen_string_literal: true

require 'prometheus_exporter'
require 'prometheus_exporter/server'
require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/rspec'
require 'prometheus_exporter/ext/instrumentation/base_stats'
require 'prometheus_exporter/ext/instrumentation/periodic_stats'
require 'prometheus_exporter/ext/server/stats_collector'
require 'prometheus_exporter/ext/server/expired_stats_collector'
require_relative 'support/rspec_test_helpers'

RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = nil

class TestInstrumentation < PrometheusExporter::Ext::Instrumentation::BaseStats
  self.type = 'test'

  def collect(data_list)
    data_list.each do |data|
      collect_data(data)
    end
  end
end

class PeriodicTestInstrumentation < PrometheusExporter::Ext::Instrumentation::PeriodicStats
  self.type = 'test'
  class << self
    attr_accessor :test_counter
  end

  def collect
    self.class.test_counter ||= 0
    self.class.test_counter += 1
    collect_data(keepalive: self.class.test_counter, labels: { foo: 'bar' })
  end
end

class TestStatsCollector < PrometheusExporter::Server::TypeCollector
  include PrometheusExporter::Ext::Server::StatsCollector
  self.type = 'test'

  register_gauge :g_metric, 'test gauge metric'
  register_counter :c_metric, 'test counter metric'
end

class TestExpiredCollector < PrometheusExporter::Server::TypeCollector
  include PrometheusExporter::Ext::Server::ExpiredStatsCollector
  self.type = 'test'
  self.ttl = 2

  unique_metric_by do |new_metric, metric|
    metric['labels'] == new_metric['labels']
  end

  register_gauge :g_metric, 'test gauge metric'
  register_counter :c_metric, 'test counter metric'
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include RSpecTestHelpers
end
