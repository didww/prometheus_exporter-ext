# frozen_string_literal: true

require_relative 'rspec/matchers'

RSpec.configure do |config|
  config.include PrometheusExporter::Ext::RSpec::Matchers
end
