#!/usr/bin/env ruby
#
# This handler creates and resolves incidents in Datadog.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems'
require 'dogapi'

module Sensu
  class Handler
    def self.run
      handler = self.new
      handler.filter
      handler.alert
    end

    def initialize
      read_event
      @dog = Dogapi::Client.new(settings['datadog']['api_key'], settings['datadog']['app_key'])
    end

    def get_action
      case @event['action']
      when 'create'
        'error'
      when 'resolve'
        'success'
      end
    end

    def read_event
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
        datadog
      end
    end

    def datadog
      incident_key = @event['client']['name'] + ' ' + @event['check']['name']
      description = @event['notification'] || [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' ')
      action = get_action
      begin
        timeout(3) do
          response = @dog.emit_event(Dogapi::Event.new(
                                              description,
                                              :msg_title => incident_key,
                                              :tags => ['sensu'],
                                              :alert_type => action,
                                              :priority => 'normal'
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
end

Sensu::Handler.run
