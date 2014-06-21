#!/usr/bin/env ruby
#
# Opsgenie Heartbeat Plugin
# ===
#
# Sends heartbeat signal to Opsgenie. If Opsgenie does not receive one atleast every 10 minutes
# it will alert. Fails with a warning if heartbeat is not configured in the Opsgenie admin
# interface.
#
# Recommended plugin interval: 200 and occurences: 3
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/https'
require 'uri'
require 'json'

class OpsgenieHeartbeat < Sensu::Plugin::Check::CLI

  option :api_key,
    :short => '-k apiKey',
    :long => '--key apiKey',
    :description => 'Opsgenie Customer API key',
    :required => true

  option :source,
    :short => '-s SOURCE',
    :long => '--source SOURCE',
    :description => 'heartbeat source',
    :required => false,
    :default => Socket.gethostbyname(Socket.gethostname).first # this should be fqdn

  option :timeout,
    :short => '-t Secs',
    :long => '--timeout Secs',
    :description => "Plugin timeout",
    :proc => proc { |a| a.to_i },
    :default => 10

  def run
    begin
      timeout(config[:timeout]) do
        response = opsgenie_heartbeat
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
  end

  def opsgenie_heartbeat
    params = {}
    params['apiKey'] = config[:api_key]
    params['source'] = config[:source]

    uri = URI.parse('https://api.opsgenie.com/v1/json/customer/heartbeat')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.request_uri, {'Content-Type' =>'application/json'})
    request.body = params.to_json
    response = http.request(request)
    JSON.parse(response.body)
  end

end
