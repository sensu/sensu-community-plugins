#!/usr/bin/env ruby
#
# PHP-FPM Metrics
# ===
#
# DESCRIPTION:
# This plugin retrives php-fpm stats, parse the response
#
# PLATFORMS:
# all
#
# DEPENDENCIES:
# sensu-plugin Ruby gem
# php-fpm stats configuration
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'uri'
require 'socket'

class PHPfpmMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :pool,
    :short => "-p POOL",
    :long => "--pool POOL",
    :description => "Full POOL name to fpm status page, example: https://yoursite.com/fpm-status?pool=POOL",
    :default => "www-data"

  option :hostname,
    :short => "-h HOSTNAME",
    :long => "--host HOSTNAME",
    :description => "Nginx hostname",
    :default => 'localhost'

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "Nginx  port",
    :default => "80"

  option :path,
    :short => "-q PATH",
    :long => "--statspath PATH",
    :description => "Path to your fpm status",
    :default => "fpm-status?pool="

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => ""

  def run

    config[:scheme] = config[:scheme] + '.' + config[:hostname] + '.php_fpm'

    config[:url] = 'http://' + config[:hostname].to_s + ':' + config[:port].to_s + '/' + config[:path].to_s + config[:pool].to_s
    config[:fqdn] = Socket.gethostname
    uri = URI.parse(config[:url])

    request = Net::HTTP::Get.new(uri.request_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    response = http.request(request)

    if response.code=="200"

    response.body.split(/\r?\n/).each do |line|
      if line.match(/^pool:\s+(\w+)/)
        connections = line.match(/^pool:\s+(\w+)/).to_a
        output "#{config[:scheme]}.pool_name", connections[1]
      end
      if line.match(/^active processes:\s+(\d+)/)
        requests = line.match(/^active processes:\s+(\d+)/).to_a
        output "#{config[:scheme]}.active_processes", requests[1]
      end
      if line.match(/^accepted conn:\s+(\d+)/)
        requests = line.match(/^accepted conn:\s+(\d+)/).to_a
        output "#{config[:scheme]}.accepted_conn", requests[1]
      end
      if line.match(/^slow requests:\s+(\d+)/)
        requests = line.match(/^slow requests:\s+(\d+)/).to_a
        output "#{config[:scheme]}.slow_requests", requests[1]
      end
      if line.match(/^max active processes:\s+(\d+)/)
        requests = line.match(/^max active processes:\s+(\d+)/).to_a
        output "#{config[:scheme]}.max_active_processes", requests[1]
      end
      if line.match(/^max children reached:\s+(\d+)/)
        requests = line.match(/^max children reached:\s+(\d+)/).to_a
        output "#{config[:scheme]}.max_children_reached", requests[1]
      end
    end
    else
      critical "error"
    end
    ok
  end
end
