#!/usr/bin/env ruby
#
# Pull TrafficServer metrics through /_stats
# ===
#
# Dependencies
# ------------
# - Ruby gem 'json'
#
# Copyright 2013 Chris Read <chris.read@gmail.com>
#
# Based on the riak metrics collector by Pete Shima <me@peteshima.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'socket'
require 'json'

class TrafficServerMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :hostname,
    :short => "-h HOSTNAME",
    :long => "--host HOSTNAME",
    :description => "TrafficServer hostname",
    :default => "localhost"

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "TrafficServer port",
    :default => "80"

  option :path,
    :short => "-q STATUSPATH",
    :long => "--statspath STATUSPATH",
    :description => "Path to stats url",
    :default => "/_stats"

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.trafficserver"

  def run
    res = Net::HTTP.start(config[:hostname], config[:port]) do |http|
      req = Net::HTTP::Get.new("#{config[:path]}")
      http.request(req)
    end

    if res.code == "200"
      stats = JSON.parse(res.body)["global"]
      process_stats(stats)
    else
      critical "Error #{res.code} connecting to trafficserver status. Please check configuration."
    end

  end

  def process_stats(stats)
    stats.select{|k, v| wanted(k)}.each do |k, v|
      output "#{config[:scheme]}.#{k.sub(/^proxy\.process\./, '')}", v
    end
    ok
  end

  def wanted(k)
    k =~ /^proxy\.process\.http\.cache/ ||
    k =~ /^proxy\.process\.http\..*_responses/ ||
    k =~ /^proxy\.process\.cache/
  end
end
