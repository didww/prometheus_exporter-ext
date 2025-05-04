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

  it 'sends matchers matched nested matchers' do
    expect { subject }.to send_metrics(
      {
        type: 'test',
        foo: a_kind_of(Integer),
        bar: 456,
        labels: { qwe: 'asd' }
      },
      {
        type: 'test',
        foo: 124,
        bar: 457,
        labels: hash_including(qwe: 'zxc')
      }
    )
  end

  it 'sends correct metrics' do
    expect { subject }.to send_metrics(
      {
        type: 'test',
        foo: 123,
        bar: 456,
        labels: { qwe: 'asd' }
      },
      {
        type: 'test',
        foo: 124,
        bar: 457,
        labels: { qwe: 'zxc' }
      }
    )
  end

  context 'when data has no labels' do
    let(:data_list) do
      [
        { foo: 123, bar: 456 },
        { foo: 124, bar: 457 }
      ]
    end

    it 'sends correct metrics' do
      expect { subject }.to send_metrics(
        {
          type: 'test',
          foo: 123,
          bar: 456,
          labels: {}
        },
        {
          type: 'test',
          foo: 124,
          bar: 457,
          labels: {}
        }
      )
    end
  end

  context 'when some data was sent previously' do
    before do
      instrumentation.collect([foo: 1, bar: 2, labels: { aaa: 'bbb' }])
    end

    it 'sends correct metrics' do
      expect { subject }.to send_metrics(
        {
          type: 'test',
          foo: 123,
          bar: 456,
          labels: { qwe: 'asd' }
        },
        {
          type: 'test',
          foo: 124,
          bar: 457,
          labels: { qwe: 'zxc' }
        }
      )
    end
  end

  context 'when instrumentation has custom labels' do
    let(:instrumentation) { TestInstrumentation.new(labels:) }
    let(:labels) { { host: 'example.com' } }

    it 'sends correct metrics' do
      expect { subject }.to send_metrics(
        {
          type: 'test',
          foo: 123,
          bar: 456,
          labels: { qwe: 'asd', host: 'example.com' }
        },
        {
          type: 'test',
          foo: 124,
          bar: 457,
          labels: { qwe: 'zxc', host: 'example.com' }
        }
      )
    end
  end

  context 'with empty data list' do
    let(:data_list) { [] }

    it 'sends correct metrics' do
      expect { subject }.not_to send_metrics
    end
  end
end
