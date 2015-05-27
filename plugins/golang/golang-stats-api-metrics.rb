#! /usr/bin/env ruby
#  encoding: UTF-8
#   golang-stats-api-metrics
#
# DESCRIPTION:
#   Get golang metrics with golang-stats-api-metrics
#   https://github.com/fukata/golang-stats-api-handler
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: uri
#   gem: socket
#   gem: oj
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Hayato Matsuura
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/https'
require 'uri'
require 'socket'
require 'oj'

class NginxMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :url,
         short: '-u URL',
         long: '--url URL',
         description: 'Full URL to go app server status page, example: https://yoursite.com/status This ignores ALL other options EXCEPT --scheme'

  option :hostname,
         short: '-h HOSTNAME',
         long: '--host HOSTNAME',
         description: 'go app server hostname',
         default: '127.0.0.1'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'go app server port',
         default: '3000'

  option :path,
         short: '-p STATUSPATH',
         long: '--statspath STATUSPATH',
         description: 'Path to your go app server status module',
         default: 'status'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.golang-stats"

  def run
    found = false
    attempts = 0
    until found || attempts >= 10
      attempts += 1
      if config[:url]
        uri = URI.parse(config[:url])
        http = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)
        if response.code == '200'
          found = true
        elsif !response.header['location'].nil?
          config[:url] = response.header['location']
        end
      else
        response = Net::HTTP.start(config[:hostname], config[:port]) do |connection|
          request = Net::HTTP::Get.new("/#{config[:path]}")
          connection.request(request)
        end
      end
    end # until

    metrics = Oj.load(response.body, mode: :compat)
    metrics.keys.each do |m|
      if m =~ /gc_pause/
        # output avarage for gc_pause array
        sum = metrics[m].reduce(0.0) { |a, e| a + e }
        # skip if there's no gc_pause
        output "#{config[:scheme]}.#{m}", sum / metrics[m].size if sum > 0
      else
        output "#{config[:scheme]}.#{m}", metrics[m]
      end
    end
    ok
  end
end
