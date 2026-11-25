# frozen_string_literal: true

require 'prometheus_exporter/ext/metric/counter_with_expire'

RSpec.describe PrometheusExporter::Ext::Metric::CounterWithExpire do
  subject(:counter) { described_class.new('test_total', 'help', ttl: 10) }

  let(:labels) { { 'pid' => '1' } }
  let(:other_labels) { { 'pid' => '2' } }

  def travel_to_monotonic(seconds)
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(seconds)
  end

  before { travel_to_monotonic(100.0) }

  describe '#initialize' do
    it 'rejects a non-numeric ttl' do
      expect { described_class.new('t', 'h', ttl: 'x') }.to raise_error(ArgumentError, /numeric/)
    end

    it 'rejects a non-positive ttl' do
      expect { described_class.new('t', 'h', ttl: 0) }.to raise_error(ArgumentError, /greater than zero/)
    end

    it 'defaults ttl to 60' do
      expect(described_class.new('t', 'h').ttl).to eq(60)
    end
  end

  describe 'accumulation' do
    it 'sums observed values like a plain counter' do
      counter.observe(2, labels)
      counter.observe(3, labels)
      expect(counter.to_h).to eq(labels => 5)
    end
  end

  describe 'expiry' do
    it 'keeps a series updated within the ttl' do
      counter.observe(1, labels)
      travel_to_monotonic(109.0)
      expect(counter.to_h).to eq(labels => 1)
    end

    it 'drops a series not updated for longer than the ttl' do
      counter.observe(1, labels)
      travel_to_monotonic(111.0)
      expect(counter.to_h).to be_empty
    end

    it 'drops it from metric_text' do
      counter.observe(1, labels)
      travel_to_monotonic(111.0)
      expect(counter.metric_text).to eq('')
    end

    it 'expires only the stale series' do
      counter.observe(1, labels)
      travel_to_monotonic(105.0)
      counter.observe(1, other_labels)
      travel_to_monotonic(111.0)
      expect(counter.to_h).to eq(other_labels => 1)
    end

    it 'restarts the ttl on every update' do
      counter.observe(1, labels)
      travel_to_monotonic(108.0)
      counter.increment(labels)
      travel_to_monotonic(116.0)
      expect(counter.to_h).to eq(labels => 2)
    end

    it 'starts from zero when a series reappears after expiry' do
      counter.observe(5, labels)
      travel_to_monotonic(111.0)
      counter.observe(1, labels)
      expect(counter.to_h).to eq(labels => 1)
    end
  end

  describe '#reset' do
    it 'sets the value and restarts the ttl' do
      counter.observe(5, labels)
      travel_to_monotonic(108.0)
      counter.reset(labels, 2)
      travel_to_monotonic(116.0)
      expect(counter.to_h).to eq(labels => 2)
    end
  end

  describe '#remove' do
    it 'forgets the expiration time too' do
      counter.observe(1, labels)
      counter.remove(labels)
      expect(counter.expiration_times).to be_empty
    end
  end
end
