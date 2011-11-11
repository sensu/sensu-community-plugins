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
# This handler reports alerts to a specified IRC channel. You need to set the options in the 
# irc.json configuration file, located by default in /etc/sensu. Set the irc_server option to
# control the IRC server to connect to, the irc_password option to set an optional channel 
# password and the irc_ssl option to true to enable an SSL connection if required. An example 
# file is contained in this irc handler directory.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'carrier-pigeon'
require 'timeout'
require 'json'

module Sensu
  class Handler
    def self.run
      handler = self.new
      handler.filter
      handler.alert
    end

    def initialize
      @settings = read_config('/etc/sensu/irc.json')
      read_event
    end

    def read_config(config_file)
      if File.readable?(config_file)
        begin
          JSON.parse(File.open(config_file, 'r').read)
        rescue JSON::ParserError => e
          puts 'configuration file must be valid JSON: ' + e
        end
      else
        puts 'configuration file does not exist or is not readable: ' + config_file
      end
    end

    def read_event
      @event = JSON.parse(STDIN.read)
    end

    def filter
      @incident_key = @event['client']['name'] + '/' + @event['check']['name']
      if @event['check']['alert'] == false
        puts 'alert disabled -- filtered event ' + @incident_key
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
      params = {
        :uri => @settings["irc_server"],
        :message => "#{@incident_key}: #{@event['check']['output']}",
        :ssl => @settings["irc_ssl"],
        :join => true,
      }
      if @settings.has_key?("irc_password")
        params[:channel_password] = @settings["irc_password"]
      end
      begin
        timeout(10) do
          CarrierPigeon.send(params)
          puts 'irc -- sent alert for ' + @incident_key + ' to IRC.'
        end
      rescue Timeout::Error
        puts 'irc -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + @incident_key
      end
    end
  end
end
Sensu::Handler.run
