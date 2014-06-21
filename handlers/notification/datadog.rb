#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'dogapi'

class DatadogNotif < Sensu::Handler

  def handle
    filter
    datadog
  end

  def get_action
    case @event['action']
    when 'create'
      'error'
    when 'resolve'
      'success'
    end
  end

  # Return a low priotiry for resolve and warn events, normal for critical and unkown
  def get_priority
    case @event['status']
    when '0', '1'
      'low'
    when '2', '3'
      'normal'
    end
  end

  def filter
    if @event['check']['alert'] == false
      puts 'alert disabled -- filtered event ' + [@event['client']['name'], @event['check']['name']].join(' : ')
      exit 0
    end
  end

  def datadog
    description = @event['notification'] || [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' ')
    action = get_action
    priority = get_priority
    tags = []
    tags.push('sensu')
    # allow for tags to be set in the configuration, this could be used to indicate environment
    tags.concat(settings['datadog']['tags']) unless settings['datadog']['tags'].nil? && !settings['datadog']['tags'].kind_of(Array)
    # add the subscibers for the event to the tags
    tags.concat(@event['check']['subscribers']) unless @event['check']['subscribers'].nil?
    begin
      timeout(3) do
        dog = Dogapi::Client.new(settings['datadog']['api_key'], settings['datadog']['app_key'])
        response = dog.emit_event(Dogapi::Event.new(
                                            description,
                                            :msg_title => @event['check']['name'],
                                            :tags => tags,
                                            :alert_type => action,
                                            :priority => priority,
                                            :source_type_name => 'nagios', # make events appear as nagios alerts so the weekly nagios report can be produced
                                            :aggregation_key => @event['check']['name']
                                          ), :host => @event['client']['name']
                        )

        begin
          if response[0] == "202"
            puts "Submitted event to Datadog"
          else
            puts "Unexpected response from Datadog: HTTP code #{response[0]}"
          end
        rescue
          puts "Could not determine whether sensu event was successfully submitted to Datadog: #{response}"
        end
      end
    rescue Timeout::Error
      puts 'Datadog timed out while attempting to ' + @event['action'] + ' a incident -- ' + incident_key
    end
  end
end
