# frozen_string_literal: true

require 'prometheus_exporter/middleware'
require_relative '../ext'

# Adds a fixed set of custom labels to every HTTP request metric.
#
#   Rails.application.middleware.unshift PrometheusExporter::Ext::RequestMiddleware, labels: { type: 'web' }
class PrometheusExporter::Ext::RequestMiddleware < PrometheusExporter::Middleware
  # @param app [#call] Rack application.
  # @param config [Hash] PrometheusExporter::Middleware config (`instrument`, `client`) plus `labels`.
  def initialize(app, config = { instrument: :alias_method, client: nil })
    @labels = (config[:labels] || {}).transform_keys(&:to_sym).freeze
    super(app, { instrument: :alias_method }.merge(config.except(:labels)))
  end

  # @return [Hash, nil]
  def custom_labels(env)
    parent = super
    return parent.merge(@labels) if parent.is_a?(Hash)

    @labels.empty? ? parent : @labels
  end
end
