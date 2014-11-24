#!/usr/bin/env ruby
#
# Skyline handler
#
# This handler sends metrics to a Skyline server 
# (https://github.com/etsy/skyline) via a UDP socket.
#
# This takes graphite like metrics (sensu's default)
# converts them to the skyline msgpack format, and then 
# sends them to opentsdb.
#
# Skyline 'server' and 'port' must be specified in a 
# config file in /etc/sensu/conf.d.
# See skyline.json for an example.
#
# Written by Derek Tracy -- http://github.com/tracyde
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'socket'
require 'msgpack'

class Skyline < Sensu::Handler
  # override filters from Sensu::Handler. not appropriate for metric handlers
  def filter; end

  def handle
    server = settings['skyline']['server']
    port = settings['skyline']['port']

    sock = UDPSocket.new
    sock.connect(server, port)

    @event['check']['output'].each_line do |metric|
      m = metric.split
      next unless m.count == 3

      # skyline needs ["metric_name", [timestamp, value]]
      name = m[0]
      value = m[1].to_f
      time = m[2].to_i
      msg = [name, [time, value]].to_msgpack
      sock.send msg, 0
    end

    sock.flush
    sock.close
  end
end
