# frozen_string_literal: true

require 'prometheus_exporter/client'
require_relative 'rspec/matchers'
require_relative 'rspec/test_client'

# Setups default client before it used anywhere.
# use `include_examples :observes_prometheus_metrics` in specs
PrometheusExporter::Client.default = PrometheusExporter::Ext::RSpec::TestClient.instance

RSpec.configure do |config|
  config.include PrometheusExporter::Ext::RSpec::Matchers

  config.before do
    PrometheusExporter::Ext::RSpec::TestClient.instance.reset
  end
end
