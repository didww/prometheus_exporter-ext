# PrometheusExporter::Ext

[![Gem Version](https://img.shields.io/gem/v/prometheus_exporter-ext.svg)](https://rubygems.org/gems/prometheus_exporter-ext)
[![Tests](https://github.com/didww/prometheus_exporter-ext/actions/workflows/tests.yml/badge.svg)](https://github.com/didww/prometheus_exporter-ext/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Extension for the [Ruby Prometheus Exporter](https://github.com/discourse/prometheus_exporter).

It adds a small, opinionated DSL on top of `prometheus_exporter` so you can build
custom instrumentations and server-side collectors with far less boilerplate, plus a
few features the base gem doesn't provide:

- **Instrumentation DSL** for both event-driven (`BaseStats`) and periodic (`PeriodicStats`) metrics.
- **Collector DSL** (`register_gauge`, `register_counter`, `register_metric`, …) to declare metrics declaratively.
- **Expiring gauges** — automatically remove or zero stale metrics via `gauge_with_expire` / `ExpiredStatsCollector`,
  so you don't keep exporting values for things that stopped reporting.
- **Built-in process CPU instrumentation** (`ProcCpu`) reading from `/proc/self/stat`.
- **A singleton web server** helper for embedding the exporter web server in your app.
- **RSpec matchers** to test your instrumentations and collectors without standing up a real server.

## Table of Contents

- [Installation](#installation)
- [How it works](#how-it-works)
- [Usage](#usage)
  - [Event-driven metrics](#event-driven-metrics)
  - [Periodic metrics](#periodic-metrics)
  - [Collectors and expiring metrics](#collectors-and-expiring-metrics)
  - [Built-in process CPU metrics](#built-in-process-cpu-metrics)
  - [Singleton web server](#singleton-web-server)
- [Testing](#testing)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Installation

Requires Ruby `>= 3.3.0` and `prometheus_exporter ~> 2.0`.

Add the gem to your application's Gemfile by executing:

    $ bundle add prometheus_exporter-ext

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install prometheus_exporter-ext

## How it works

The flow mirrors `prometheus_exporter`: an **instrumentation** runs inside your
application process and ships data points to the exporter server; a **collector**
runs inside the exporter server, receives those data points, and exposes them as
Prometheus metrics on the `/metrics` endpoint.

This gem gives you base classes for both sides, paired by a shared `self.type`:

```
your app code ──▶ Instrumentation#collect_data ──▶ exporter server ──▶ Collector ──▶ /metrics
                  (self.type = 'my')                                   (self.type = 'my')
```

## Usage

### Event-driven metrics

Use `BaseStats` when metrics should be sent in response to a particular event
(e.g. after running an operation).

Create the instrumentation:

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

Then send metrics from your code:

```ruby
time_start = Time.current.to_i
begin
  MyOperation.run
ensure
  duration = Time.current.to_i - time_start
  Prometheus::MyInstrumentation.new.collect(duration, 'my_operation')

  # you can add additional labels or override the client
  Prometheus::MyInstrumentation.new(
    client: PrometheusExporter::Client.new(...),
    labels: { foo: 'bar' }
  ).collect(duration, 'my_operation')
end
```

### Periodic metrics

Use `PeriodicStats` when metrics should be sent periodically at a given frequency.

Create the instrumentation:

```ruby
# lib/prometheus/my_periodic_instrumentation.rb
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

Then start it once (it runs on a background thread):

```ruby
Prometheus::MyPeriodicInstrumentation.start

# you can override the frequency in seconds
Prometheus::MyPeriodicInstrumentation.start(frequency: 60)

# you can also add additional labels or override the client
Prometheus::MyPeriodicInstrumentation.start(
  client: PrometheusExporter::Client.new(...),
  labels: { foo: 'bar' }
)

# to stop the instrumentation:
Prometheus::MyPeriodicInstrumentation.stop
```

### Collectors and expiring metrics

On the server side, declare a collector with the same `type`. There are two flavors.

#### `StatsCollector` with per-metric expiration

`register_gauge_with_expire` removes or zeroes a single metric once it expires,
while leaving other metrics (e.g. counters) untouched.

```ruby
require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/server/stats_collector'

module Prometheus
  class MyCollector < ::PrometheusExporter::Server::TypeCollector
    include ::PrometheusExporter::Ext::Server::StatsCollector
    self.type = 'my'

    # `register_gauge_with_expire` removes or zeroes the metric once it expires.
    # :strategy defaults to `:removing`; available options are `:removing` and `:zeroing`.
    # :ttl defaults to 60 (seconds); any numeric greater than 0 can be used.
    register_gauge_with_expire :last_duration_seconds, 'duration of last operation execution', ttl: 300

    register_counter :duration_seconds_sum, 'sum of operation execution durations'
    register_counter :duration_seconds_count, 'count of operation execution runs'
  end
end
```

#### `ExpiredStatsCollector` for whole-collector expiration

Use `ExpiredStatsCollector` when you want **all** metric data removed after expiration.

```ruby
require 'prometheus_exporter/ext'
require 'prometheus_exporter/ext/server/expired_stats_collector'

module Prometheus
  class MyCollector < ::PrometheusExporter::Server::TypeCollector
    include ::PrometheusExporter::Ext::Server::ExpiredStatsCollector
    self.type = 'my'
    self.ttl = 300 # default 60

    # Optionally expire an old metric when a specific new metric is collected.
    # If this block returns true, the old metric is removed.
    unique_metric_by do |new_metric, old_metric|
      new_metric['labels'] == old_metric['labels']
    end

    register_gauge :last_duration_seconds, 'duration of last operation execution'
    register_counter :duration_seconds_sum, 'sum of operation execution durations'
    register_counter :duration_seconds_count, 'count of operation execution runs'
  end
end
```

### Built-in process CPU metrics

The gem ships a ready-to-use instrumentation/collector pair that reports cumulative
CPU time of the current process, read from `/proc/self/stat` (Linux only).

In your application process:

```ruby
require 'prometheus_exporter/ext/instrumentation/proc_cpu'

# `type` is required and is added as a label, so you can distinguish
# CPU usage of different process kinds (web, sidekiq, etc).
PrometheusExporter::Ext::Instrumentation::ProcCpu.start(type: 'web')
```

In the exporter server:

```ruby
require 'prometheus_exporter/ext/server/proc_cpu_collector'

# register the collector with the exporter server, e.g.:
server.collector.register_collector(PrometheusExporter::Ext::Server::ProcCpuCollector.new)
```

This exposes `proc_cpu_usage_seconds_total` (a counter, in core-seconds) labeled with
`type`, `pid`, and `hostname`.

### Singleton web server

`SingletonWebServer` wraps `PrometheusExporter::Server::WebServer` with class-level
start/stop helpers, making it easy to embed and configure the exporter web server
from a single place in your app.

```ruby
require 'prometheus_exporter/ext/server/singleton_web_server'

PrometheusExporter::Ext::Server::SingletonWebServer.start(
  bind: '0.0.0.0',
  port: 9394
)

# register collectors against the running server
PrometheusExporter::Ext::Server::SingletonWebServer.configure_collector do |collector|
  collector.register_collector(Prometheus::MyCollector.new)
end

# optionally protect /metrics with basic auth
PrometheusExporter::Ext::Server::SingletonWebServer.build_htpasswd(
  '/path/to/.htpasswd',
  username: 'prometheus',
  password: 'secret'
)

# shut it down
PrometheusExporter::Ext::Server::SingletonWebServer.stop
```

## Testing

The gem provides RSpec matchers so you can test instrumentations and collectors
without running a real exporter server. Require them in your spec helper:

```ruby
require 'prometheus_exporter/ext/rspec'
```

Test an instrumentation with the `send_metrics` matcher:

```ruby
RSpec.describe Prometheus::MyInstrumentation do
  describe '#collect' do
    subject { described_class.new.collect(duration, operation) }

    let(:duration) { 1.23 }
    let(:operation) { 'test' }

    it 'sends prometheus metrics' do
      expect { subject }.to send_metrics(
        [
          type: 'my',
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

Test a collector with the metric matchers
(`a_gauge_metric`, `a_counter_metric`, `a_gauge_with_expire_metric`, …):

```ruby
RSpec.describe Prometheus::MyCollector do
  describe '#collect' do
    subject { collector.metrics }

    let(:collector) { described_class.new }
    let(:metric) do
      {
        type: 'my',
        labels: { operation_name: 'test' },
        last_duration_seconds: 1.2,
        duration_seconds_sum: 3.4,
        duration_seconds_count: 1
      }
    end

    let(:collect_data) do
      collector.collect(metric.deep_stringify_keys)
    end

    before { collect_data }

    it 'observes prometheus metrics' do
      expect(collector.metrics).to contain_exactly(
        a_gauge_with_expire_metric('my_last_duration_seconds').with(1.2, metric[:labels]),
        a_counter_metric('my_duration_seconds_sum').with(3.4, metric[:labels]),
        a_counter_metric('my_duration_seconds_count').with(1, metric[:labels])
      )
    end

    context 'when collected data is expired' do
      let(:collect_data) do
        super()
        sleep 60.1 # when gauge_with_expire ttl is 60
      end

      it 'observes empty prometheus metrics for the expired gauge' do
        expect(collector.metrics).to contain_exactly(
          a_gauge_with_expire_metric('my_last_duration_seconds').empty,
          a_counter_metric('my_duration_seconds_sum').with(3.4, metric[:labels]),
          a_counter_metric('my_duration_seconds_count').with(1, metric[:labels])
        )
      end
    end
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push git
commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/didww/prometheus_exporter-ext.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
