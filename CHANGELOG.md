## [Unreleased]

## [0.4.0] - 2026-11-25
- drop EOL Ruby 3.2, test on Ruby 3.3 and 3.4, raise `required_ruby_version` to `>= 3.3.0`
- add `PrometheusExporter::Ext::Metric::CounterWithExpire`, `register_counter_with_expire` and the `a_counter_with_expire_metric` RSpec matcher
- `ProcCpuCollector` drops series not updated for 300 seconds (set `ProcCpuCollector.ttl` to change it); specs that matched it with `a_counter_metric` need `a_counter_with_expire_metric`
- add `on_error:` option and `safe_collect` helper to `BaseStats`; an `on_error` handler that raises falls back to a warning
- add a collector-wide `ttl` setting to `StatsCollector` for expiring metrics registered without `ttl:`
- add `Instrumentation::ActiveJob` and `Server::ActiveJobCollector`; `enqueued_total` leaves out retry re-enqueues, which `retried_total` counts
- add `Instrumentation::SolidQueue` and `Server::SolidQueueCollector`
- add `PrometheusExporter::Ext::RequestMiddleware` that adds static labels to request metrics

## [0.3.2] - 2026-06-11
- fix gemspec missing `spec.files` so the published gem actually ships its source files (0.3.1 and earlier shipped empty)

## [0.3.1] - 2024-05-04
- ProcCpu add hostname label

## [0.3.0] - 2024-05-04
- replace ProcStat with ProcCpu

## [0.2.4] - 2024-05-03
- add PrometheusExporter::Ext::Server::ProcStatCollector

## [0.2.3] - 2024-05-03
- add PrometheusExporter::Ext::Instrumentation::ProcStat

## [0.2.2] - 2023-12-08
- fix send_metrics RSpec matcher

## [0.2.1] - 2023-12-06
- add gauge_with_expire, add tests, update readme

## [0.2.0] - 2023-12-06
- remove gauge_with_time, add expired_stats_collector, add tests

## [0.1.0] - 2023-11-26
- Initial release
