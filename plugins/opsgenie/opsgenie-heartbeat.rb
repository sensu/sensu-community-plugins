#!/usr/bin/env ruby
#
# Opsgenie Heartbeat Plugin
# ===
#
# Sends heartbeat signal to Opsgenie. If Opsgenie does not receive one atleast every 10 minutes
# it will alert. Fails with a warning if heartbeat is not configured in the Opsgenie admin
# interface.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require "net/https"
require "uri"
require "json"

class OpsgenieHeartbeat < Sensu::Plugin::Check::CLI

  option :customer_key,
    :short => "-k customerKey",
    :long => "--key customerKey",
    :description => "Opsgenie Customer API key",
    :required => true

  def run
    begin
      timeout(5) do
        response = opsgenie_heartbeat()
        case response['code']
        when 200
          ok 'heartbeat sent'
        when 8
          warning 'heartbeat not enabled'
        else
          critical 'unexpected response code ' + response.code.to_s
        end
      end
    rescue Timeout::Error
      critical 'heartbeat timed out'
    end
  end

  def opsgenie_heartbeat()
    params = {}
    params["customerKey"] = config[:customer_key]

    uri = URI.parse("https://api.opsgenie.com/v1/json/customer/heartbeat")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.request_uri,initheader = {'Content-Type' =>'application/json'})
    request.body = params.to_json
    response = http.request(request)
    JSON.parse(response.body)
  end

end
