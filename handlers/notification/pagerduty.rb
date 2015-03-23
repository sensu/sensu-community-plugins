#!/usr/bin/env ruby
#
# This handler creates and resolves PagerDuty incidents, refreshing
# stale incident details every 30 minutes
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# Dependencies:
#
#   sensu-plugin >= 1.0.0
#

require 'sensu-handler'
require 'redphone/pagerduty'

class Pagerduty < Sensu::Handler
  option :json_config,
         description: 'Configuration name',
         short: '-j JSONCONFIG',
         long: '--json JSONCONFIG',
         default: 'pagerduty'

  def incident_key
    source = @event['check']['source'] || @event['client']['name']
    [source, @event['check']['name']].join('/')
  end

  def handle
    if @event['check']['pager_team']
      api_key = settings[config[:json_config]][@event['check']['pager_team']]['api_key']
    else
      api_key = settings[config[:json_config]]['api_key']
    end
    incident_key_prefix = settings[config[:json_config]]['incident_key_prefix']
    description_prefix = settings[config[:json_config]]['description_prefix']
    begin
      timeout(10) do
        response = case @event['action']
                   when 'create'
                     Redphone::Pagerduty.trigger_incident(
                       service_key: api_key,
                       incident_key: [incident_key_prefix, incident_key].compact.join(''),
                       description: [description_prefix, event_summary].compact.join(' '),
                       details: @event
                     )
                   when 'resolve'
                     Redphone::Pagerduty.resolve_incident(
                       service_key: api_key,
                       incident_key: [incident_key_prefix, incident_key].compact.join('')
                     )
                    end
        if response['status'] == 'success'
          puts 'pagerduty -- ' + @event['action'].capitalize + 'd incident -- ' + incident_key
        else
          puts 'pagerduty -- failed to ' + @event['action'] + ' incident -- ' + incident_key
        end
      end
    rescue Timeout::Error
      puts 'pagerduty -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + incident_key
    end
  end
end
