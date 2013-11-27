#!/usr/bin/env ruby
# This handler creates and resolves PagerDuty incidents, refreshing
# stale incident details every 30 minutes
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'uri'
require 'net/http'
require 'net/https'

class VictorOps < Sensu::Handler

  def handle
    config = settings['victorops']
    incident_key = @event['client']['name'] + '/' + @event['check']['name']

    description = @event['check']['notification']
    description ||= [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' : ')
    host = @event['client']['name']
    entity_id = incident_key
    state_message = description
    begin
      timeout(10) do
        response = case @event['action']
        when 'create'
          message_type = 'CRITICAL'
        when 'resolve'
          message_type = 'RECOVERY'
        end

payload = <<-eos
{
  "message_type": "#{message_type}",
  "state_message": "#{state_message.chomp}",
  "entity_id": "#{entity_id}",
  "host_name": "#{host}",
  "monitoring_tool": "sensu"
}
eos
        uri   = URI("#{config['api_url']}/#{config['routing_key']}")
        https = Net::HTTP.new(uri.host, uri.port)

        https.use_ssl = true

        request      = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
        request.body = payload
        response     = https.request(request)

        if response.code == '200'
          puts 'victorops -- ' + @event['action'].capitalize + 'd incident -- ' + incident_key
        else
          puts 'victorops -- failed to ' + @event['action'] + ' incident -- ' + incident_key
        end
      end
    rescue Timeout::Error
      puts 'victorops -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + incident_key
    end
  end

end
