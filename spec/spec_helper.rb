# frozen_string_literal: true

require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/rspec/matchers'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include PrometheusExporter::Ext::RSpec::Matchers
end
