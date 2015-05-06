#! /usr/bin/env ruby
#
#   check-mtu_spec
#
# DESCRIPTION:
#  rspect tests for check-mtu
#
# OUTPUT:
#   RSpec testing output: passes and failures info
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   rspec
#
# USAGE:
#   For Rspec Testing
#
# NOTES:
#   For Rspec Testing
#
# LICENSE:
#   Copyright 2015 Robin <robin81@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require_relative '../../../plugins/network/check-mtu'

require 'plugin_stub'

describe CheckMTU  do

  include_context :plugin_stub

  let(:checker) { described_class.new }
  let(:checker_9000) { described_class.new }
  let(:checker_no_file) { described_class.new }
  let(:exit_code) { nil }

  ## Simulate the system MTU to be 1500
  before(:each) do
    def checker.locate_mtu_file
      'spec/fixtures/plugins/network/check-mtu-1500'
    end
    def checker.ok(*_args)
      exit 0
    end
    def checker.warning(*_args)
      exit 1
    end
    def checker.critical(*_args)
      exit 2
    end
  end

  it 'returns ok by default with 1500 MTU ' do
    begin
      checker.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 0
  end

  it 'returns ok by default with 1500 MTU (with warn setting)' do
    checker.config[:warn] = true
    begin
      checker.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 0
  end

  it 'returns critical if we ask it to check for 9000 while it has 1500 MTU interface' do
    checker.config[:mtu] = 9000
    begin
      checker.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 2
  end

  it 'returns critical if we ask it to check for 9000 while it has 1500 MTU interface (with warn setting)' do
    checker.config[:mtu] = 9000
    checker.config[:warn] = true
    begin
      checker.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 1
  end

  ## Simulate system MTU to be 9000
  before(:each) do
    def checker_9000.locate_mtu_file
      'spec/fixtures/plugins/network/check-mtu-9000'
    end
    def checker_9000.ok(*_args)
      exit 0
    end
    def checker_9000.warning(*_args)
      exit 1
    end
    def checker_9000.critical(*_args)
      exit 2
    end
  end

  it 'returns critical if we ask it to check for 1500 MTU while we have 9000 MTU interface' do
    begin
      checker_9000.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 2
  end

  it 'returns warning if we ask it to check for 1500 MTU while we have 9000 MTU interface (with warn setting on)' do
    checker_9000.config[:warn] = true
    begin
      checker_9000.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 1
  end

  it 'returns ok if we ask it to check for 9000 MTU while we have 9000 MTU interface' do
    checker_9000.config[:mtu] = 9000
    begin
      checker_9000.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 0
  end

  it 'returns ok if we ask it to check for 9000 MTU while we have 9000 MTU interface (with warn setting on)' do
    checker_9000.config[:warn] = true
    checker_9000.config[:mtu] = 9000
    begin
      checker_9000.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 0
  end

  ## This should never happen. This simulates a situation (which may not happen) whereby a system's MTU info cannot be read
  before(:each) do
    def checker_no_file.locate_mtu_file
      'no_existing_file'
    end
    def checker_no_file.ok(*_args)
      exit 0
    end
    def checker_no_file.warning(*_args)
      exit 1
    end
    def checker_no_file.critical(*_args)
      exit 2
    end
  end

  it 'returns critical' do
    begin
      checker_no_file.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 2
  end

  it 'returns warning (with warn setting is on)' do
    checker_no_file.config[:warn] = true
    begin
      checker_no_file.run
    rescue SystemExit => e
      exit_code = e.status
    end
    expect(exit_code).to eq 1
  end
end
