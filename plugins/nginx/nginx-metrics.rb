#!/usr/bin/env ruby
#
# Pull nginx metrics for backends through stub status module
# ===
#
# Created by Pete Shima - me@peteshima.com
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'socket'

class NginxMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :hostname,
    :short => "-h HOSTNAME",
    :long => "--host HOSTNAME",
    :description => "Nginx hostname",
    :required => true

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "Nginx  port",
    :default => "80"

  option :path,
    :short => "-q STATUSPATH",
    :long => "--statspath STATUSPATH",
    :description => "Path to your stub status module",
    :default => "nginx_status"

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => Socket.gethostname

  def run
    res = Net::HTTP.start(config[:hostname], config[:port]) do |http|
      req = Net::HTTP::Get.new("/#{config[:path]}")
      http.request(req)
    end

    res.body.split(/\r?\n/).each do |line|
      if connections = line.match(/^Active connections:\s+(\d+)/).to_a
        output "#{config[:scheme]}.nginx.active_connections", connections[1]
      end
      if requests = line.match(/^\s+(\d+)\s+(\d+)\s+(\d+)/).to_a
        output "#{config[:scheme]}.nginx.accepted", requests[1]
        output "#{config[:scheme]}.nginx.handled", requests[2]
        output "#{config[:scheme]}.nginx.handles", requests[3]
      end
      if queue = line.match(/^Reading:\s+(\d+).*Writing:\s+(\d+).*Waiting:\s+(\d+)/).to_a
        output "#{config[:scheme]}.nginx.reading", queue[1]
        output "#{config[:scheme]}.nginx.writing", queue[2]
        output "#{config[:scheme]}.nginx.waiting", queue[3]
      end
    end

    ok
  end

end
