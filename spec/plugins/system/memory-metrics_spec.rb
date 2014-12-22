require File.expand_path('../../../../plugins/system/memory-metrics', __FILE__)

require 'plugin_stub'

describe MemoryGraphite do
  include_context :plugin_stub
  let(:checker) { described_class.new }

  before(:each) do
    def checker.meminfo_output
      File.open('spec/fixtures/plugins/system/meminfo_output.txt', 'r')
    end
  end

  it 'is able to parse metrics output' do
    metrics = checker.metrics_hash

    expect(metrics['total']).to eq(1_922_732 * 1024)
    expect(metrics['free']).to eq(573_744 * 1024)
    expect(metrics['buffers']).to eq(123_772 * 1024)
    expect(metrics['cached']).to eq(298_216 * 1024)
    expect(metrics['swapTotal']).to eq(2_047_992 * 1024)
    expect(metrics['swapFree']).to eq(1_907_192 * 1024)
    expect(metrics['dirty']).to eq(284 * 1024)
  end

  it 'calculates dependent metrics correctly' do
    metrics = checker.metrics_hash

    expect(metrics['swapUsed']).to eq(140_800 * 1024)
    expect(metrics['used']).to eq(1_348_988 * 1024)
    expect(metrics['usedWOBuffersCaches']).to eq(927_000 * 1024)
    expect(metrics['freeWOBuffersCaches']).to eq(995_732 * 1024)
    expect(metrics['swapUsedPercentage']).to eq(6)
  end
end
