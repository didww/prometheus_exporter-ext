# frozen_string_literal: true

RSpec.describe PrometheusExporter::Ext::Instrumentation::BaseStats do
  subject do
    instrumentation.collect(data_list)
  end

  let(:instrumentation) { TestInstrumentation.new }
  let(:data_list) do
    [
      { foo: 123, bar: 456, labels: { qwe: 'asd' } },
      { foo: 124, bar: 457, labels: { qwe: 'zxc' } }
    ]
  end

  it 'sends metrics' do
    expect { subject }.to send_metrics
  end

  it 'sends exactly 2 metrics' do
    expect { subject }.to send_metrics.times(2)
  end

  it 'sends correct metrics' do
    expect { subject }.to send_metrics(
      [
        {
          type: 'test',
          foo: 123, bar: 456,
          labels: { qwe: 'asd' },
          metric_labels: {}
        },
        {
          type: 'test',
          foo: 124, bar: 457,
          labels: { qwe: 'zxc' },
          metric_labels: {}
        }
      ]
    )
  end

  context 'with empty data list' do
    let(:data_list) { [] }

    it 'sends correct metrics' do
      expect { subject }.not_to send_metrics
    end
  end
end
