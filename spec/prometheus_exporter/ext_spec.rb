# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext do
  it 'has a version number' do
    expect(PrometheusExporter::Ext::VERSION).not_to be_nil
  end
end
