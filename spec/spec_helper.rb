# frozen_string_literal: true

require 'prometheus_exporter'
require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/rspec'
require 'prometheus_exporter/ext/instrumentation/base_stats'

class TestInstrumentation < PrometheusExporter::Ext::Instrumentation::BaseStats
  self.type = 'test'

  def collect(data_list)
    data_list.each do |data|
      collect_data(data)
    end
  end
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
