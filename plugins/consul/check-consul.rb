#! /usr/bin/env ruby
#
#   check-consul-leader
#
# DESCRIPTION:
#   This plugin checks if consul is up and reachable. It then checks
#   the status/leader and ensures there is a current leader.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#   gem: rubysl-resolv
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'resolv'

class ConsulStatus < Sensu::Plugin::Check::CLI
  option :server,
         description: 'consul server',
         short: '-s SERVER',
         long: '--server SERVER',
         default: '127.0.0.1'

  option :port,
         description: 'consul http port',
         short: '-p PORT',
         long: '--port PORT',
         default: '8500'

  def valid_ip(ip)
    case ip.to_s
    when Resolv::IPv4::Regex
      return true
    when Resolv::IPv6::Regex
      return true
    else
      return false
    end
  end

  def strip_ip(str)
    ipv4_regex = '(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
    ipv6_regex = '\[.*\]'
    if str =~ /^.*#{ipv4_regex}.*$/
      return str.match(/#{ipv4_regex}/)
    elsif str =~ /^.*#{ipv6_regex}.*$/
      return str[/#{ipv6_regex}/][1..-2]
    else
      return str
    end
  end

  def run
    r = RestClient::Resource.new("http://#{config[:server]}:#{config[:port]}/v1/status/leader", timeout: 5).get
    if r.code == 200
      if valid_ip(strip_ip(r.body))
        ok 'Consul is UP and has a leader'
      else
        critical 'Consul is UP, but it has NO leader'
      end
    else
      critical 'Consul is not responding'
    end
  rescue Errno::ECONNREFUSED
    critical 'Consul is not responding'
  rescue RestClient::RequestTimeout
    critical 'Consul Connection timed out'
  end
end
