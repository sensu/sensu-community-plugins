#! /usr/bin/env ruby
#
# kegbot check
#
# DESCRIPTION:
#   Check keg capacity on a kegerator running kegbot
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#
# USAGE:
#   check-kegbot.rb --url <KEGBOT_API_URL>
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Eric Heydrick <eheydrick@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'rest-client'

#
# Check Kegbot
#
class Kegbot < Sensu::Plugin::Check::CLI
  option :url,
         description: 'Kegbot API URL',
         short: '-u URL',
         long: '--url URL',
         required: true

  option :warn,
         description: 'Warning threshold',
         short: '-w WARNING',
         long: '--warning WARNING',
         proc: proc(&:to_i),
         default: 15

  option :crit,
         description: 'Critical threshold',
         short: '-c CRITICAL',
         long: '--critical CRITICAL',
         proc: proc(&:to_i),
         default: 5

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

    warn_taps = []
    crit_taps = []

    taps.each do |tap|
      message = tap['name'] + ' ' + "(#{tap['current_keg']['beverage']['name']})" + ': ' "#{tap['current_keg']['percent_full'].round}% remaining"

      if tap['current_keg']['percent_full'].round <= config[:crit]
        crit_taps << message
      elsif tap['current_keg']['percent_full'].round <= config[:warn]
        warn_taps << message
      end
    end

    if warn_taps.empty? && crit_taps.empty?
      ok 'All kegs above thresholds'
    elsif crit_taps.size > 0
      critical crit_taps.join(', ')
    elsif warn_taps.size > 0
      warning warn_taps.join(', ')
    end
  end
end
