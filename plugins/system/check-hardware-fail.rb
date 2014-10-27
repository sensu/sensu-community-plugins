#!/usr/bin/ruby

#
# Check dmesg for failing hardware
#
# Detects things like overheating CPUs, dying hard drives, etc.
#
# Originally by Shank Feek, greatly modified by Alan Smith.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckHardwareFail < Sensu::Plugin::Check::CLI

  def run
    errors = `dmesg`.lines.grep(/\[Hardware Error\]/)
    unless errors.empty?
      critical "Hardware Error Detected"
    end

    ok "Hardware OK"
  end
end
