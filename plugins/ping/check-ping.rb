#!/usr/bin/env ruby
# Check-ping
# ===
#
# This is a simple Ping check script for Sensu, Currently works with
#  ICMP as well as HTTP ping.
#
# Requires "net-ping" gem
#
# Examples:
#
#   check-ping -h host -t type -p port    => port option is for HTTP ping
#
#  Default host is "google.com", change to if you dont want to pass host
# option
#  Author Deepak Mohan Dass   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/ping'

class CheckPING < Sensu::Plugin::Check::CLI

  option :port,
    :short => '-p port',
    :default => "80"

  option :host,
    :short => '-h host',
    :default => 'google.com'

  option :type,
    :short => '-t type',
    :default => 'HTTP'

  def run
    pt = nil
    ping_type = config[:type].upcase
    case ping_type
    when 'HTTP'
      pt = Net::Ping::HTTP.new(config[:host], config[:port], 10)
    when 'ICMP'
      pt = Net::Ping::ICMP.new(config[:host], config[:port], 10)
    when 'TCP'
      pt = Net::Ping::TCP.new(config[:host], config[:port], 10)
    else
      unknown "Unknown type specified: #{config[:type]}"
    end
    if !pt.nil?
      if pt.ping?
        ok "#{ping_type} ping successful for host: #{config[:host]}"
      else
        critical "#{ping_type} ping unsuccessful for host: #{config[:host]}"
      end
    end
  end
end
