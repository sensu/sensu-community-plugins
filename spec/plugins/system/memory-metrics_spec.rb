require File.expand_path('../../../../plugins/system/memory-metrics', __FILE__)

require 'plugin_stub'

describe MemoryGraphite do
  include_context :plugin_stub
  let(:checker) { described_class.new }

  before(:each) do
    def checker.meminfo_output
      File.open('spec/fixtures/meminfo_output.txt', 'r')
    end
  end

  it 'is able to parse metrics output' do
    metrics = checker.metrics_hash

    expect(metrics['total']).to eq(1922732*1024)
    expect(metrics['free']).to eq(573744*1024)
    expect(metrics['buffers']).to eq(123772*1024)
    expect(metrics['cached']).to eq(298216*1024)
    expect(metrics['swapTotal']).to eq(2047992*1024)
    expect(metrics['swapFree']).to eq(1907192*1024)
    expect(metrics['dirty']).to eq(284*1024)
  end

  it 'calculates dependent metrics correctly' do
    metrics = checker.metrics_hash

    expect(metrics['swapUsed']).to eq(140800*1024)
    expect(metrics['used']).to eq(1348988*1024)
    expect(metrics['usedWOBuffersCaches']).to eq(927000*1024)
    expect(metrics['freeWOBuffersCaches']).to eq(995732*1024)
    expect(metrics['swapUsedPercentage']).to eq(6)
  end
end
