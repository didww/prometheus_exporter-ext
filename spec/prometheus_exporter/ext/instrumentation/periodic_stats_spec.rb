# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Instrumentation::PeriodicStats do
  describe '.start' do
    subject do
      PeriodicTestInstrumentation.start(frequency:)
      sleep(wait_seconds)
    end

    let(:frequency) { 2 }
    let(:wait_seconds) { 0.1 } # can't be 0 because thread requires few milliseconds to start

    after do
      PeriodicTestInstrumentation.stop
      PeriodicTestInstrumentation.test_counter = nil
    end

    it 'sends 1 metric' do
      expect { subject }.to send_metrics(
        {
          keepalive: 1,
          type: 'test',
          labels: { foo: 'bar' }
        }
      )
    end

    context 'when wait for frequency seconds more' do
      let(:wait_seconds) { super() + frequency } # 2.1

      it 'sends 2 metrics' do
        expect { subject }.to send_metrics(
          {
            keepalive: 1,
            type: 'test',
            labels: { foo: 'bar' }
          },
          {
            keepalive: 2,
            type: 'test',
            labels: { foo: 'bar' }
          }
        ).ordered
      end
    end

    context 'when wait for frequency+1 seconds more' do
      let(:wait_seconds) { super() + frequency + 1 } # 3.1

      it 'sends 2 metrics' do
        expect { subject }.to send_metrics(
          {
            keepalive: 1,
            type: 'test',
            labels: { foo: 'bar' }
          },
          {
            keepalive: 2,
            type: 'test',
            labels: { foo: 'bar' }
          }
        ).ordered
      end
    end
  end
end
