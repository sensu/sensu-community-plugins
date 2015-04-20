#! /usr/bin/env ruby
#
# kegbot-metrics
#
# DESCRIPTION:
#   Output kegerator metrics from Kegbot
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#
# USAGE:
#   kegbot-metrics.rb --url <KEGBOT_API_URL>
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Eric Heydrick <eheydrick@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'rest-client'

#
# Collect Kegbot metrics
#
class KegbotMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :url,
         description: 'Kegbot API URL',
         short: '-u URL',
         long: '--url URL',
         required: true

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'kegbot'

  def run
    begin
      response = RestClient.get("#{config[:url]}/taps")
      taps = JSON.parse(response.body)['objects']
    rescue Errno::ECONNREFUSED
      critical 'Kegbot connection refused'
    rescue RestClient::RequestTimeout
      critical 'Kegbot connection timed out'
    rescue => e
      critical "Kegbot API call failed: #{e.message}"
    end

    taps.each do |tap|
      tap_name = tap['name'].gsub(' ', '_')
      output "#{config[:scheme]}.#{tap_name}.percent_full", tap['current_keg']['percent_full']
      output "#{config[:scheme]}.#{tap_name}.volume_ml_remain", tap['current_keg']['volume_ml_remain']
    end
    ok
  end
end
