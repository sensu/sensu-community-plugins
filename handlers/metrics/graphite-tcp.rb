#!/usr/bin/env ruby
#
# Grapite TCP handler
# ===
#
# This handler sends metrics to a Graphite server via
# TCP socket.
#
# Compatible checks should generate output in the format:
#   metric.path.one value timestamp\n
#   metric.path.two value timestamp\n
#
# Graphite 'server' and 'port' must be specified in a config file
# in /etc/sensu/conf.d.  See graphite_tcp.json for an example.
#
# Copyright 2012 Joe Miller <http://joemiller.me>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'

class Graphite < Sensu::Handler

  # override filters from Sensu::Handler. not appropriate for metric handlers
  def filter; end

  def handle
    graphite_server = settings['graphite']['server']
    graphite_port = settings['graphite']['port']

    metrics = @event['check']['output']

    begin
      timeout(3) do
        sock = TCPSocket.new(graphite_server, graphite_port)
        sock.puts metrics
        sock.close
      end
    rescue Timeout::Error
      puts "graphite -- timed out while sending metrics"
    rescue => error
      puts "graphite -- failed to send metrics : #{error}"
    end
  end

end
