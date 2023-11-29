# PrometheusExporter::Ext

Extended Prometheus Exporter for Ruby

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add prometheus_exporter-ext

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install prometheus_exporter-ext

## Usage

### When metrics should be send on particular event
create instrumentation
```ruby
# lib/prometheus/my_instrumentation.rb
require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/instrumentation/base_stats'

module Prometheus
  class MyInstrumentation < ::PrometheusExporter::Ext::Instrumentation::BaseStats
    self.type = 'my'

    def collect(duration, operation)
      collect_data(
        labels: { operation_name: operation },
        last_duration_seconds: duration,
        duration_seconds_sum: duration,
        duration_seconds_count: 1
      )
    rescue StandardError => e
      Rails.logger.error("Failed to send metrics Prometheus #{self.class.name} #{e}")
      Rails.error.report(e, handled: true, severity: :error, context: { prometheus: self.class.name })
    end
  end
end
```

then send metrics from your code
```ruby
  time_start = Time.current.to_i
begin
  MyOperation.run
ensure
  duration = Time.current.to_i - time_start
  Prometheus::MyInstrumentation.new.collect(duration, 'my_operation')
  ## you can add additional labels or override client
  Prometheus::MyInstrumentation.new(
    client: PrometheusExporter::Client.new(...),
    metric_labels: { foo: 'bar' }
  ).collect(duration)
end
```

so metrics will be collected by
```ruby
require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/server/stats_collector'

module Prometheus
  class MyCollector < ::PrometheusExporter::Server::TypeCollector
    include ::PrometheusExporter::Ext::Server::StatsCollector
    self.type = 'my'

    # The :gauge_with_time will allow you to write timestamp to gauge metric when value were observer.
    # It will replace data with same labels and recalculate timestamp.
    register_metric :last_duration_seconds, :gauge_with_time, 'duration of last operation execution'
    register_metric :task_duration_seconds_sum, :counter, 'sum of operation execution durations'
    register_metric :task_duration_seconds_count, :counter, 'sum of operation execution runs'
  end
end
```

### When metrics should be send periodically with given frequency
create instrumentation
```ruby
# lib/prometheus/my_instrumentation.rb
require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/instrumentation/periodic_stats'

module Prometheus
  class MyPeriodicInstrumentation < ::PrometheusExporter::Ext::Instrumentation::PeriodicStats
    self.type = 'my'

    def collect
      count = MyItem.processed.count
      last_duration = MyItem.processed.last&.duration
      collect_data(
        labels: { some_label: 'some_value' },
        last_processed_duration: last_duration || 0,
        processed_count: count
      )
    rescue StandardError => e
      Rails.logger.error("Failed to send metrics Prometheus #{self.class.name} #{e}")
      Rails.error.report(e, handled: true, severity: :error, context: { prometheus: self.class.name })
    end
  end
end
```

then send metrics from your code
```ruby
Prometheus::MyInstrumentation.start
## you can override frequency in seconds
Prometheus::MyInstrumentation.start(frequency: 60)
## also you can add additional labels or override client
Prometheus::MyInstrumentation.start(
  client: PrometheusExporter::Client.new(...),
  metric_labels: { foo: 'bar' }
)
# to stop instrumentation call `Prometheus::MyInstrumentation.stop`
```

so metrics will be collected by
```ruby
require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/server/stats_collector'

module Prometheus
  class MyCollector < ::PrometheusExporter::Server::TypeCollector
    include ::PrometheusExporter::Ext::Server::StatsCollector
    self.type = 'my'

    # The :gauge_with_time will allow you to write timestamp to gauge metric when value were observer.
    # It will replace data with same labels and recalculate timestamp.
    register_metric :last_processed_duration, :gauge_with_time, 'duration of last processed record'
    register_metric :processed_count, :gauge_with_time, 'count of processed records'
  end
end
```

### You also can easily test your instrumentations and collectors using new matchers

instrumentation test
```ruby
require 'prometheus_exporter/ext/rspec'

RSpec.describe Prometheus::MyInstrumentation do
  describe '#collect' do
    subject { described_class.new.collect(duration, operation) }
    let(:duration) { 1.23 }
    let(:operation) { 'test' }

    it 'sends prometheus metrics' do
      expect { subject }.to send_metrics(
        [
          type: 'my',
          metric_labels: {},
          labels: { operation_name: operation },
          last_duration_seconds: duration,
          duration_seconds_sum: duration,
          duration_seconds_count: 1
        ]
      )
    end
  end
end
```

collector test
```ruby
RSpec.describe Prometheus::MyCollector do
  describe '#collect' do
    subject do
      collector.collect(metric.deep_stringify_keys)
    end

    let(:collector) { described_class.new }
    let(:metric) do
      {
        type: 'my',
        metric_labels: {},
        labels: { operation_name: 'test' },
        last_duration_seconds: 1.2,
        duration_seconds_sum: 3,4,
        duration_seconds_count: 1
      }
    end

    it 'observes prometheus metrics' do
      subject
      expect(collector.metrics).to contain_exactly(
        a_gauge_with_time_metric('my_last_duration_seconds').with([1.2, ms_since_epoch], metric[:labels]),
        a_counter_metric('my_duration_seconds_sum').with(3.4, metric[:labels]),
        a_counter_metric('my_duration_seconds_count').with(1, metric[:labels])
      )
    end
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/didww/prometheus_exporter-ext.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
