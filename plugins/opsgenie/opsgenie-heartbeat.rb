#! /usr/bin/env ruby
#
#   opsgenie-heatbeat
#
# DESCRIPTION:
#   Sends heartbeat signal to Opsgenie. If Opsgenie does not receive one atleast every 10 minutes
#   it will alert. Fails with a warning if heartbeat is not configured in the Opsgenie admin
#   interface.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: uri
#   gem: json
#   gem: net-https
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Recommended plugin interval: 200 and occurences: 3
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/https'
require 'uri'
require 'json'

class OpsgenieHeartbeat < Sensu::Plugin::Check::CLI
  option :api_key,
         short: '-k apiKey',
         long: '--key apiKey',
         description: 'Opsgenie API key',
         required: true

  option :name,
         short: '-n Name',
         long: '--name Name',
         description: 'Heartbeat Name',
         default: 'Default'

  option :timeout,
         short: '-t Secs',
         long: '--timeout Secs',
         description: 'Plugin timeout',
         proc: proc(&:to_i),
         default: 10

  def run
    timeout(config[:timeout]) do
      response = opsgenie_heartbeat
      puts response
      case response['code']
      when 200
        ok 'heartbeat sent'
      when 8
        warning 'heartbeat not enabled'
      else
        unknown 'unexpected response code ' + response.code.to_s
      end
    end
  rescue Timeout::Error
    warning 'heartbeat timed out'
  end

  def opsgenie_heartbeat
    params = {}
    params['apiKey'] = config[:api_key]
    params['name'] = config[:name]

    uri = URI.parse('https://api.opsgenie.com/v1/json/heartbeat/send')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    request.body = params.to_json
    response = http.request(request)
    JSON.parse(response.body)
  end
end
