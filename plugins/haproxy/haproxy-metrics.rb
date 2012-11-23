#!/usr/bin/env ruby
#
# Pull haproxy metrics for backends
# ===
#
# TODO: backend pool single node stats.
#
# Copyright 2012 Pete Shima <me@peteshima.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'socket'
require 'csv'
require 'uri'

class HAProxyMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :connection,
    :short => "-c HOSTNAME|SOCKETPATH",
    :long => "--connect HOSTNAME|SOCKETPATH",
    :description => "HAproxy web stats hostname or path to stats socket",
    :required => true

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "HAproxy web stats port",
    :default => "80"

  option :path,
    :short => "-q STATUSPATH",
    :long => "--statspath STATUSPATH",
    :description => "HAproxy web stats path",
    :default => "/"

  option :username,
    :short => "-u USERNAME",
    :long => "--user USERNAME",
    :description => "HAproxy web stats username"

  option :password,
    :short => "-p PASSWORD",
    :long => "--pass PASSWORD",
    :description => "HAproxy web stats password"

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.haproxy"

  option :backends,
    :description => "comma-separated list of backends to fetch stats from. Default is all backends",
    :short => "-f BACKEND1[,BACKEND2]",
    :long => "--backends BACKEND1[,BACKEND2]",
    :proc => Proc.new { |l| l.split(',') },
    :default => Array.new()  # an empty list means show all backends


  def critical(message)
    output "CRITICAL: #{message}"
  end

  def get_stats
    uri = URI.parse(config[:connection])

    if uri.is_a?(URI::Generic) and File.socket?(uri.path)
      socket = UNIXSocket.new(config[:connection])
      socket.puts("show stat")
      out = socket.read
      socket.close
    else
      res = Net::HTTP.start(config[:connection], config[:port]) do |http|
        req = Net::HTTP::Get.new("/#{config[:path]};csv;norefresh")
        unless config[:username].nil? then
          req.basic_auth config[:username], config[:password]
        end
        http.request(req)
      end
      out = res.body
    end
    return out
  rescue
    return nil
  end

  def run
    out = nil
    1.upto(3) do |i|
      out = get_stats();
      break unless out.to_s.length.zero?
      sleep(1)
    end

    parsed = CSV.parse(out)
    parsed.shift
    parsed.each do |line|
      next if line[1] != 'BACKEND'
      if config[:backends].length > 0
        next unless config[:backends].include? line[0]
      end
      output "#{config[:scheme]}.#{line[0]}.session_current", line[4]
      output "#{config[:scheme]}.#{line[0]}.session_total", line[7]
      output "#{config[:scheme]}.#{line[0]}.bytes_in", line[8]
      output "#{config[:scheme]}.#{line[0]}.bytes_out", line[9]
      output "#{config[:scheme]}.#{line[0]}.connection_errors", line[13]
    end

    ok
  end

end
