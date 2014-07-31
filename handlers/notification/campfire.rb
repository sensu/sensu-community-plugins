#!/usr/bin/env ruby
#
# Sensu Handler: campfire
#
# Copyright 2012, AJ Christensen <aj@junglist.gen.nz>
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

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'tinder'

class Campfire < Sensu::Handler

  def incident_key
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def campfire
    Tinder::Campfire.new(settings["campfire"]["account"], :ssl => true, :token => settings["campfire"]["token"])
  end

  def room
    unless settings["campfire"]["room_id"].nil?
      return campfire.find_room_by_id(settings["campfire"]["room_id"])
    else
      return campfire.find_room_by_name(settings["campfire"]["room"])
    end
  end

  def handle
    description = @event['notification'] || [
                                               @event['client']['name'],
                                               @event['check']['name'],
                                               @event['check']['output'],
                                               @event['client']['address'],
                                               @event['client']['subscriptions'].join(',')
                                            ].join(' : ')
    begin
      timeout(3) do
        if room.speak("#{incident_key}: #{description}")
          puts 'campfire -- ' + @event['action'].capitalize + 'd incident -- ' + incident_key
        else
          puts 'campfire -- failed to ' + @event['action'] + ' incident -- ' + incident_key
        end
      end
    rescue Timeout::Error
      puts 'campfire -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + incident_key
    end
  end

end
