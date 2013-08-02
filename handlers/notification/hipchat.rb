#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'hipchat'
require 'timeout'

class HipChatNotif < Sensu::Handler

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    hipchatmsg = HipChat::Client.new(settings["hipchat"]["apikey"])
    room = settings["hipchat"]["room"]
    message = @event['check']['notification'] || @event['check']['output']

    begin
      timeout(3) do
        if @event['action'].eql?("resolve")
          hipchatmsg[room].send('Sensu', "RESOLVED - [#{event_name}] - #{message}.", :color => 'green')
        else
          hipchatmsg[room].send('Sensu', "ALERT - [#{event_name}] - #{message}.", :color => 'red', :notify => true)
        end
      end
    rescue Timeout::Error
      puts "hipchat -- timed out while attempting to message #{room}"
    end
  end

end
