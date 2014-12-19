#! /usr/bin/env ruby
#
#  check-ping
#
# DESCRIPTION:
#   This is a simple Ping check script for Sensu.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: net-ping
#
# USAGE:
#   check-ping -h host -T timeout [--report]
#
# NOTES:
#
# LICENSE:
#   Deepak Mohan Dass   <deepakmdass88@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/ping'

class CheckPING < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h host',
         default: 'localhost'

  option :timeout,
         short: '-T timeout',
         proc: proc(&:to_i),
         default: 5

  option :count,
         short: '-c count',
         description: 'The number of ping requests',
         proc: proc(&:to_i),
         default: 1

  option :interval,
         short: '-i interval',
         description: 'The number of seconds to wait between ping requests',
         proc: proc(&:to_f),
         default: 1

  option :warn_ratio,
         short: '-W ratio',
         description: 'Warn if successful ratio is under this value',
         proc: proc(&:to_f),
         default: 0.5

  option :critical_ratio,
         short: '-C ratio',
         description: 'Critical if successful ratio is under this value',
         proc: proc(&:to_f),
         default: 0.2

  option :report,
         short: '-r',
         long: '--report',
         description: 'Attach MTR report if ping is failed',
         default: false

  def run
    result = []
    pt = Net::Ping::External.new(config[:host], nil, config[:timeout])
    config[:count].times do |i|
      sleep(config[:interval]) unless i == 0
      result[i] = pt.ping?
    end

    successful_count = result.count(true)
    total_count = config[:count]
    success_ratio = successful_count / total_count.to_f

    if success_ratio > config[:warn_ratio]
      success_message = "ICMP ping successful for host: #{config[:host]}"
      ok success_message
    else
      failure_message = "ICMP ping unsuccessful for host: #{config[:host]} (successful: #{successful_count}/#{total_count})"

      if config[:report]
        report = `mtr --curses --report-cycles=1 --report --no-dns #{config[:host]}`
        failure_message = failure_message + "\n" + report
      end

      if success_ratio <= config[:critical_ratio]
        critical failure_message
      else
        warning failure_message
      end
    end
  end
end
