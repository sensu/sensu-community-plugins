#!/usr/bin/env ruby
#
# This handler logs sensu events to Splunkstorm.
#
# Requires the rest-client and json gems
# gem install rest-client
# gem install json
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'rest-client'
require 'json'

API_HOST = 'api.splunkstorm.com'
API_VERSION = 1
API_ENDPOINT = 'inputs/http'
URL_SCHEME = 'https'

module Sensu
  class Handler
    def self.run
      handler = self.new
      handler.filter
      handler.alert
    end

    def initialize
      @event = JSON.parse(STDIN.read)
    end

    def filter
      if @event['check']['alert'] == false
        puts 'alert disabled -- filtered event ' + [@event['client']['name'], @event['check']['name']].join(' : ')
        exit 0
      end
    end

    def alert
      refresh = (60.fdiv(@event['check']['interval']) * 30).to_i
      if @event['occurrences'] == 1 || @event['occurrences'] % refresh == 0
        splunkstorm
      end
    end

    def splunkstorm
      incident_key = @event['client']['name'] + ' ' + @event['check']['name']
      event_params = {:sourcetype => 'sensu-server', :host => @event['client']['name'], :project => settings['splunkstorm']['project_id']}

      begin
        timeout(3) do
          api_url = "#{URL_SCHEME}://#{API_HOST}"
          api_params = URI.escape(event_params.collect{|k, v| "#{k}=#{v}"}.join('&'))
          endpoint_path = "#{API_VERSION}/#{API_ENDPOINT}?#{api_params}"

          request = RestClient::Resource.new(api_url, :user => 'sensu', :password => settings['splunkstorm']['access_token'])

          response = request[endpoint_path].post(JSON.dump(@event))
          puts response
        end
      rescue Timeout::Error
        puts 'splunkstorm -- timed out while attempting to log incident -- ' + incident_key
      end
    end
  end
end
Sensu::Handler.run
