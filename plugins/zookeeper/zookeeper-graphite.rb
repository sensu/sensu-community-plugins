#!/usr/bin/env ruby
#
# Zookeeper metrics based on mntr command
#
#
# DESCRIPTION:
#   This plugin retrieves metrics from 'mntr' zookeeper command
#
# OUTPUT:
#   Graphite plain-text format (name value timestamp\n)
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# EXAMPLES:
#
# LICENSE:
#   Copyright 2014 SuperSonic, Ltd <devops@supersonicads.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'timeout'

class ZookeeperGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "Zookeeper Host",
    :default  => '127.0.0.1'

  option :port,
    :short => "-p PORT",
    :long => "--port PORT",
    :description => "Zookeeper Port",
    :proc => proc {|p| p.to_i },
    :default => 2181

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.zookeeper"

  def run
    begin
      Timeout.timeout(3) do
        TCPSocket.open(config[:host], config[:port]) do |socket|
          socket.print "mntr\r\n"
          socket.close_write
          recv = socket.read
          recv.each_line do |line|
            (key, value) = line.split("\t")
            output "#{config[:scheme]}.#{key}", value.to_i if value.match(/^[\d]+$/)
          end
        end
      end
      ok
    rescue Errno::ECONNREFUSED
      critical "connection refused to zookeeper on #{config[:host]}:#{config[:port]}"
    rescue Timeout::Error
      unknown "timed out connecting to zookeeper on #{config[:host]}:#{config[:port]}"
    end
#    rescue
#     puts "Can't connect to port #{config[:port]}"
#     exit(1)
  end
end
