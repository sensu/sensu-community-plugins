#!/usr/bin/env ruby
#
# This is a simple Ping check script for Sensu.
#
# Requires "net-ping" gem
#
# Examples:
#
#   check-ping -h host -T timeout [--report]
#
#  Default host is "localhost"
#
#  Author Deepak Mohan Dass   <deepakmdass88@gmail.com>
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/ping'

class CheckPING < Sensu::Plugin::Check::CLI

  option :host,
    :short => '-h host',
    :default => 'localhost'

  option :timeout,
    :short => '-T timeout',
    :default => '5'

  option :report,
    :short => '-r',
    :long => '--report',
    :description => "Attach MTR report if ping is failed",
    :default => false

  def run
    pt = Net::Ping::External.new(config[:host], nil, config[:timeout].to_i)
    if pt.ping?
      ok "ICMP ping successful for host: #{config[:host]}"
    else
      message = "ICMP ping unsuccessful for host: #{config[:host]}"
      if config[:report]
        report = `mtr --curses --report-cycles=1 --report --no-dns #{config[:host]}`
        message = message + "\n" + report
      end
      critical message
    end
  end
end
