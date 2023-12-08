# frozen_string_literal: true

require 'prometheus_exporter/server/web_server'
require_relative '../../ext'

module PrometheusExporter::Ext::Server
  class SingletonWebServer < PrometheusExporter::Server::WebServer
    class << self
      attr_accessor :server

      def start(opts)
        self.server = new(opts)
        server.start
      end

      def stop
        server.stop
        self.server = nil
      end

      def build_htpasswd(htpasswd_path, username:, password:)
        htpasswd = WEBrick::HTTPAuth::Htpasswd.new(htpasswd_path)
        htpasswd.set_passwd PrometheusExporter::DEFAULT_REALM, username, password
        htpasswd.flush
      end

      # @yieldparam collector [PrometheusExporter::Server::Collector]
      def configure_collector
        yield server.collector
      end
    end
  end
end
