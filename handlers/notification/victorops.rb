#!/usr/bin/env ruby
# This handler creates and resolves victorops incidents
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# arguments:
#   - settingsname: Sensu settings name, defaults to victorops
#   - routingkey: VictorOps routing key

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'uri'
require 'net/http'
require 'net/https'
require 'json'

class VictorOps < Sensu::Handler
  option :settingsname,
         description: 'Sensu settings name',
         short: '-n NAME',
         long: '--name NAME',
         default: 'victorops'

  option :routing_key,
         description: 'Routing key',
         short: '-r KEY',
         long: '--routingkey KEY',
         default: nil

  def handle
    # validate that we have settings
    unless defined? settings[config[:settingsname]] && !settings[config[:settingsname]].nil?
      fail "victorops.rb sensu setting '#{config[:settingsname]}' not found or empty"
    end
    unless defined? settings[config[:settingsname]]['api_url'] && !settings[config[:settingsname]]['api_url'].nil?
      fail "victorops.rb sensu setting '#{config[:settingsname]}.api_url' not found or empty"
    end
    api_url = settings[config[:settingsname]]['api_url']

    # validate that we have a routing key - command arguments take precedence
    routing_key = config[:routing_key]
    routing_key = settings[config[:settingsname]]['routing_key'] if routing_key.nil?

    unless defined? routing_key && !routing_key.nil?
      fail 'routing key not defined, should be in Sensu settings or passed via command arguments'
    end

    incident_key = @event['client']['name'] + '/' + @event['check']['name']

    description = @event['check']['notification']
    description ||= [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' : ')
    host = @event['client']['name']
    entity_id = incident_key
    state_message = description
    begin
      timeout(10) do

        case @event['action']
        when 'create'
          case @event['check']['status']
          when 1
            message_type = 'WARNING'
          else
            message_type = 'CRITICAL'
          end
        when 'resolve'
          message_type = 'RECOVERY'
        end

        payload = Hash.new
        payload[:message_type] = message_type
        payload[:state_message] = state_message.chomp
        payload[:entity_id] = entity_id
        payload[:host_name] = host
        payload[:monitoring_tool] = 'sensu'

        # Add in client data
        payload[:check] = @event['check']
        payload[:client] = @event['client']

        uri   = URI("#{api_url.chomp('/')}/#{routing_key}")
        https = Net::HTTP.new(uri.host, uri.port)

        https.use_ssl = true

        request      = Net::HTTP::Post.new(uri.path)
        request.body = payload.to_json
        response     = https.request(request)

        if response.code == '200'
          puts "victorops -- #{@event['action'].capitalize}'d incident -- #{incident_key}"
        else
          puts "victorops -- failed to #{@event['action']} incident -- #{incident_key}"
          puts "victorops -- response: #{response.inspect}"
        end
      end
    rescue Timeout::Error
      puts 'victorops -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + incident_key
    end
  end
end
