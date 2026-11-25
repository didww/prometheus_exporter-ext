# frozen_string_literal: true

require 'prometheus_exporter/ext/request_middleware'

RSpec.describe PrometheusExporter::Ext::RequestMiddleware do
  subject(:middleware) { described_class.new(app, config) }

  let(:app) { ->(_env) { [200, {}, ['ok']] } }
  let(:client) { instance_double(PrometheusExporter::Client, send_json: nil) }
  let(:config) { { labels:, instrument: nil, client: } }
  let(:labels) { { type: 'web' } }

  describe '#custom_labels' do
    it 'returns the configured labels' do
      expect(middleware.custom_labels({})).to eq(type: 'web')
    end

    context 'with string keys' do
      let(:labels) { { 'type' => 'web' } }

      it 'symbolizes the keys' do
        expect(middleware.custom_labels({})).to eq(type: 'web')
      end
    end

    context 'without labels' do
      let(:config) { { instrument: nil, client: } }

      it 'returns nil' do
        expect(middleware.custom_labels({})).to be_nil
      end
    end

    context 'with empty labels' do
      let(:labels) { {} }

      it 'returns nil' do
        expect(middleware.custom_labels({})).to be_nil
      end
    end
  end

  describe '#call' do
    it 'sends the labels with the request metric' do
      middleware.call({})

      expect(client).to have_received(:send_json).with(hash_including(custom_labels: { type: 'web' }))
    end

    context 'without labels' do
      let(:config) { { instrument: nil, client: } }

      it 'sends no custom_labels' do
        middleware.call({})

        expect(client).to have_received(:send_json).with(hash_excluding(:custom_labels))
      end
    end
  end

  describe 'instrumentation' do
    let(:config) { { labels:, client: }.merge(extra_config) }
    let(:extra_config) { {} }

    before do
      stub_const('PG::Connection', Class.new)
      allow(PrometheusExporter::Instrumentation::MethodProfiler).to receive(:patch)
    end

    it 'keeps the default alias_method instrumentation' do
      middleware

      expect(PrometheusExporter::Instrumentation::MethodProfiler)
        .to have_received(:patch).with(PG::Connection, anything, :sql, instrument: :alias_method)
    end

    context 'with explicit instrument: nil' do
      let(:extra_config) { { instrument: nil } }

      it 'does not instrument' do
        middleware

        expect(PrometheusExporter::Instrumentation::MethodProfiler).not_to have_received(:patch)
      end
    end
  end
end
