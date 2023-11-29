# frozen_string_literal: true

require 'singleton'

module PrometheusExporter::Ext::RSpec
  class TestClient
    include Singleton

    def initialize
      super
      reset
    end

    def metrics
      @metrics.dup
    end

    def send_json(data)
      @metrics << data
    end

    def reset
      @metrics = []
    end

    def stop
      nil
    end
  end
end
