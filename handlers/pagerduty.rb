#!/usr/bin/env ruby
#
# This handler creates and resolves PagerDuty incidents, refreshing
# stale incident details every 30 minutes
#
# Copyright 2011 Sonian, Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'redphone/pagerduty'

PAGERDUTY_API_KEY = 'foobar'

module Sensu
  class Handler
    def self.run
      handler = self.new
      handler.filter
      handler.alert
    end

    def initialize
      read_event
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
        pagerduty
      end
    end

    def pagerduty
      incident_key = @event['client']['name'] + '/' + @event['check']['name']
      description = @event['notification'] || [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' : ')
      begin
        timeout(3) do
          response = case @event['action']
          when 'create'
            Redphone::Pagerduty.trigger_incident(
              :service_key => PAGERDUTY_API_KEY,
              :incident_key => incident_key,
              :description => description,
              :details => @event
            )
          when 'resolve'
            Redphone::Pagerduty.resolve_incident(
              :service_key => PAGERDUTY_API_KEY,
              :incident_key => incident_key
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
end
Sensu::Handler.run
