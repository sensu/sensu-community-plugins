#! /usr/bin/env ruby
#
#   newrelic-metrics
#
# DESCRIPTION:
#   Pull new relic metrics
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   example commands
#
# NOTES:
#   this is setup to only work if you have a single account under
#   your api key.
#
# LICENSE:
#   Copyright 2012 Pete Shima <me@peteshima.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'net/https'
require 'uri'
require 'socket'
require 'crack'

class NewRelicMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :apikey,
         short: '-k APIKEY',
         long: '--apikey APIKEY',
         description: 'Your New Relic API Key',
         required: true

  option :appname,
         short: '-n APPNAME',
         long: '--name APPNAME',
         description: 'Name of the new relic app you want',
         required: true

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.newrelic"

  def run
    rpm = 'http://rpm.newrelic.com'

    url = URI.parse(rpm)

    res = Net::HTTP.start(url.host, url.port) do |http|
      req = Net::HTTP::Get.new('/accounts.xml?include=application_health')
      req.add_field('x-api-key', config[:apikey])
      http.request(req)
    end

    stats = Crack::XML.parse(res.body)

    app = stats['accounts'].first['applications'].find { |v| v['name'] == config[:appname] }
    app['threshold_values'].each do |v|
      metric_name = v['name'].gsub(/\s+/, '_').downcase
      output "#{config[:scheme]}.#{metric_name}", v['metric_value']
    end

    ok
  end
end
