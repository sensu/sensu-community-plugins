#! /usr/bin/env ruby
#
#   check-windows-cpu-load
#
# DESCRIPTION:
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Windows
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#  Tested on Windows 2008RC2.
#
# LICENSE:
#   Jean-Francois Theroux <me@failshell.io>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckWindowsCpuLoad < Sensu::Plugin::Check::CLI
  option :warning,
         short: '-w WARNING',
         default: 85,
         proc: proc(&:to_i)

  option :critical,
         short: '-c CRITICAL',
         default: 95,
         proc: proc(&:to_i)

  def run
    io = IO.popen("typeperf -sc 1 \"processor(_total)\\% processor time\"")
    cpu_load = io.readlines[2].split(',')[1].gsub(/"/, '').to_i
    critical "CPU at #{cpu_load}%" if cpu_load > config[:critical]
    warning "CPU at #{cpu_load}%" if cpu_load > config[:warning]
    ok "CPU at #{cpu_load}%"
  end
end
