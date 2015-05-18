require File.expand_path('../../../../plugins/system/check-hardware-fail', __FILE__)

require 'plugin_stub'

describe CheckHardwareFail do
  include_context :plugin_stub
  let(:checker) { described_class.new }

  before(:each) do
    def checker.dmesg_input
      # https://robots.thoughtbot.com/fight-back-utf-8-invalid-byte-sequences
      "hi \255"
    end
    def checker.ok(*args)
      'ok notification'
    end
    def checker.critical(*args)
      'critical notification'
    end
  end

  it 'will not bomb out if there are invalid utf8 chars in dmesg' do
    expect { checker.run }.not_to raise_error
  end
end
