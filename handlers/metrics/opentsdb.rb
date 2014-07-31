#!/usr/bin/env ruby
#
# OpenTSDB handler
#
# This handler sends metrics to a OpenTSDB server via
# TCP socket.
#
# This takes graphite like metrics (sensu's default)
# converts them to the opentsdb format, and then sends
# them to opentsdb.  Each metric is sent individually
# to work around a bug in netty.
# https://github.com/OpenTSDB/opentsdb/issues/100
#
# In the future this really should just be a mutator to a tcp pipe,
# but at the moment you cannot chain mutators.
#
# OpenTSDB 'server', 'port', and 'hostname_length'  must be
# specified in a config file in /etc/sensu/conf.d.
# See opentsdb.json for an example.
#
# Written by Zach Dunn -- @SillySophist or http://github.com/zadunn
# HEAVILY inspired by Jeremy Carroll <http://carrollops.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'json'
require 'timeout'

class OpenTSDB < Sensu::Handler
# override filters from Sensu::Handler. not appropriate for metric handlers
  def filter; end

  def handle
    tsd_server = settings['opentsdb']['server']
    tsd_port = settings['opentsdb']['port']
    host_name_len = settings['opentsdb']['hostname_length']
    metrics = @event['check']['output']
    check_name = @event['check']['name']
    sock = TCPSocket.new(tsd_server, tsd_port)

    begin
      metrics.split("\n").each do |output_line|
        mutated_output = ""
        (metric_name, metric_value, epoch_time) = output_line.split("\t")
        tokens = metric_name.split('.')
        host_name = tokens[0..host_name_len].join('.')
        short_metric = tokens[(host_name_len + 1)]
        long_metric = tokens[(host_name_len + 2)..-1].join('.')
        mutated_output = "put #{short_metric} #{epoch_time} #{metric_value} check=#{check_name} host=#{host_name} metric=#{long_metric}"
        timeout(3) do
          sock.puts mutated_output
        end
      end
    ensure
      sock.flush
      sock.close
    end

    rescue Timeout::Error
      puts "opentsdb -- timed out while sending metrics"
    rescue => error
      puts "opentsdb -- failed to send metrics : #{error}"
  end
end
