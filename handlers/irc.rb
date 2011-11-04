#!/usr/bin/env ruby
# Copyright 2011 James Turnbull
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Sensu IRC Handler
# ===
#
# This handler reports alerts to a specified IRC channel. You need to set the IRC_SERVER
# contant in this file to your requested nick, password, IRC server, port and channel. If 
# you wish to use SSL please set IRC_SSL to true.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'carrier-pigeon'

IRC_SERVER = 'irc://sensubot:password@irc.freenode.net:6667#channel'
IRC_SSL = false

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
      if (@event['check']['alert'] == false || @event['client']['subscriptions'].include?('spot'))
        log(
          :name => 'Alert Disabled',
          :reason => 'Filtered event ' + [@event['client']['name'], @event['check']['name']].join(' : ')
        )
        exit 0
      end
    end

    def alert
      refresh = (60.fdiv(@event['check']['interval']) * 30).to_i
      if @event['occurrences'] == 1 || @event['occurrences'] % refresh == 0
        irc
      end
    end

    def irc
      incident_key = @event['client']['name'] + '/' + @event['check']['name']
      description = [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' : ')
      begin
        timeout(8) do
          CarrierPigeon.send(:uri => IRC_SERVER, :message => description, :ssl => IRC_SSL)
        end
      rescue Timeout::Error
        max_attempts -= 1
        if max_attempts > 0
          retry
        else
          log(
            :name => 'Timeout',
            :reason => "Timed out while attempting send #{incident_key} to IRC"
          )
        end
      end
    end

    def log(line_hash={})
      line = 'name="' + line_hash[:name] + '" event_id=handler:default'
      line += ' reason="' + line_hash[:reason] + '"' unless line_hash[:reason].nil?
      line += ' action="' + line_hash[:action] + '"' unless line_hash[:action].nil?
      puts line
    end
  end
end
Sensu::Handler.run
