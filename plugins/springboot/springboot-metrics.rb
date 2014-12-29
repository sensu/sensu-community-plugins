#! /usr/bin/env ruby
#
#   springboot-metrics
#
# DESCRIPTION:
#   get metrics from Spring Boot 1.2.x application using actuator endpoints
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: uri
#
# USAGE:
#
#   All metrics:
#     springboot-metrics.rb --host=192.168.1.1 &
#       --port=8081 &
#       --username=admin --password=secret &
#       --path=/metrics --counters --gauges
#   Exclude counters and gauges:
#     springboot-metrics.rb --host=192.168.1.1 &
#       --port=8081 &
#       --username=admin --password=secret --path=/metrics
#
# NOTES:
#   Check with Spring Boot 1.2.0 actuator endpoints
#
# LICENSE:
#   Copyright 2014 Victor Pechorin <dev@pechorina.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'net/https'
require 'json'
require 'uri'

class SpringBootMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Your spring boot actuator endpoint',
         required: true,
         default: 'localhost'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'Your app port',
         required: true,
         default: 8080

  option :username,
         short: '-u USERNAME',
         long: '--username USERNAME',
         description: 'Your app username',
         required: false

  option :password,
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         description: 'Your app password',
         required: false

  option :path,
         short: '-e PATH',
         long: '--path PATH',
         description: 'Metrics endpoint path',
         required: true,
         default: '/metrics'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         required: true,
         default: "#{Socket.gethostname}.springboot_metrics"

  option :counters,
         description: 'Include counters',
         short: '-c',
         long: '--counters',
         boolean: true,
         default: false

  option :gauges,
         description: 'Include gauges',
         short: '-g',
         long: '--gauges',
         boolean: true,
         default: false

  def json_valid?(str)
    JSON.parse(str)
    return true
  rescue JSON::ParserError
    return false
  end

  def run
    endpoint = "http://#{config[:host]}:#{config[:port]}"
    url      = URI.parse(endpoint)

    begin
      res = Net::HTTP.start(url.host, url.port) do |http|
        req = Net::HTTP::Get.new(config[:path])
        if config[:username] && config[:password]
          req.basic_auth(config[:username], config[:password])
        end
        http.request(req)
      end
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET,
           EOFError, Net::HTTPBadResponse,
           Net::HTTPHeaderSyntaxError, Net::ProtocolError,
           Errno::ECONNREFUSED => e
      critical e
    end

    if json_valid?(res.body)
      json = JSON.parse(res.body)
      json.each do |key, val|
        if key.to_s.match(/^counter\.(.+)/)
          output(config[:scheme] + '.' + key, val) if config[:counters]
        elsif key.to_s.match(/^gauge\.(.+)/)
          output(config[:scheme] + '.' + key, val) if config[:gauges]
        else
          output(config[:scheme] + '.' + key, val)
        end
      end
    else
      critical 'Response contains invalid JSON'
    end

    ok
  end
end
