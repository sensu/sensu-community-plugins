#!/usr/bin/env ruby
#
# Check Windows's CPU usage
# ===
#
# Tested on Windows 2008RC2.
#
# Jean-Francois Theroux <me@failshell.io>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckWindowsCpuLoad < Sensu::Plugin::Check::CLI
  option :warning,
         short: '-w WARNING',
         default: 85

  option :critical,
         short: '-c CRITICAL',
         default: 95

  def run
    io = IO.popen("typeperf -sc 1 \"processor(_total)\\% processor time\"")
    cpu_load = io.readlines[2].split(',')[1].gsub(/"/, '').to_i
    critical "CPU at #{cpu_load}%" if cpu_load > config[:critical]
    warning "CPU at #{cpu_load}%" if cpu_load > config[:warning]
    ok "CPU at #{cpu_load}%"
  end
end
