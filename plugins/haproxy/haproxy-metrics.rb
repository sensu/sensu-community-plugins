#!/usr/bin/env ruby
#
# Pull haproxy metrics for backends
# ===
#
# If you are occassionally seeing "nil output" from this check, make sure you have
# sensu-plugin >= 0.1.7. This will provide a better error message.
#
# TODO: backend pool single node stats.
#
# Copyright 2012 Pete Shima <me@peteshima.com>, Joe Miller <https://github.com/joemiller>
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
    :default => Array.new  # an empty list means show all backends

  option :server_metrics,
    :description => "Add metrics for backend servers",
    :boolean => true,
    :long => "--server-metrics",
    :default => false

  option :retries,
    :description => "Number of times to retry fetching stats from haproxy before giving up.",
    :short => "-r RETRIES",
    :long => "--retries RETRIES",
    :default => 3,
    :proc => Proc.new { |i| i.to_i }

  option :retry_interval,
    :description => "Interval (seconds) between retries",
    :short => "-i SECONDS",
    :long => "--retry_interval SECONDS",
    :default => 1,
    :proc => Proc.new { |i| i.to_i }

  def get_stats
    uri = URI.parse(config[:connection])

    if uri.is_a?(URI::Generic) && File.socket?(uri.path)
      socket = UNIXSocket.new(config[:connection])
      socket.puts("show stat")
      out = socket.read
      socket.close
    else
      res = Net::HTTP.start(config[:connection], config[:port]) do |http|
        req = Net::HTTP::Get.new("/#{config[:path]};csv;norefresh")
        unless config[:username].nil?
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
    1.upto(config[:retries]) do |i|
      out = get_stats;
      break unless out.to_s.length.zero?
      sleep(config[:retry_interval])
    end

    if out.to_s.length.zero?
      warning "Unable to fetch stats from haproxy after #{config[:retries]} attempts"
    end

    parsed = CSV.parse(out)
    parsed.shift
    parsed.each do |line|
      if config[:backends].length > 0
        next unless config[:backends].include? line[0]
      end

      if line[1] == 'BACKEND'
        output "#{config[:scheme]}.#{line[0]}.session_current", line[4]
        output "#{config[:scheme]}.#{line[0]}.session_total", line[7]
        output "#{config[:scheme]}.#{line[0]}.bytes_in", line[8]
        output "#{config[:scheme]}.#{line[0]}.bytes_out", line[9]
        output "#{config[:scheme]}.#{line[0]}.connection_errors", line[13]
      elsif config[:server_metrics]
        output "#{config[:scheme]}.#{line[0]}.#{line[1]}.session_total", line[7]
      end

    end

    ok
  end

end
