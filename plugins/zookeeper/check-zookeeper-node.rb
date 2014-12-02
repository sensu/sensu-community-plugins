#!/usr/bin/env ruby
#
# Check Zookeeper Node status
#
#
# DESCRIPTION:
#   This plugin check zookeeper node status based on following commands: ruok,isro,mntr
#
# OUTPUT:
#   plain-text
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

  def run
    begin
      Timeout.timeout(3) do
        TCPSocket.open(config[:host], config[:port]) do |socket|
          socket.print "ruok\r\n"
          socket.close_write
          unless socket.gets == 'imok'
            critical "zookeeper on #{config[:host]}:#{config[:port]} is not ok"
          end
        end

        TCPSocket.open(config[:host], config[:port]) do |socket|
          socket.print "isro\r\n"
          unless socket.gets == 'rw'
            critical "zookeeper on #{config[:host]}:#{config[:port]} is not writable"
          end
        end

        TCPSocket.open(config[:host], config[:port]) do |socket|
          socket.print "mntr\r\n"
          socket.close_write
          recv = socket.read
          recv.each_line do |line|
            if line.match(/^zk_server_state/)
              ok "zookeeper on #{config[:host]}:#{config[:port]} is #{line.split("\t")[1]}"
            end
          end
        end
      end
    rescue Errno::ECONNREFUSED
      critical "connection refused to zookeeper on #{config[:host]}:#{config[:port]}"
    rescue Timeout::Error
      unknown "timed out connecting to zookeeper on #{config[:host]}:#{config[:port]}"
    end
  end
end
