#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'hipchat'


class HipChatNotif < Sensu::Handler

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    hipchatmsg = HipChat::Client.new(settings["hipchat"]["apikey"])
    message = @event['check']['notification'] || @event['check']['output']

    if @event['action'].eql?("resolve")
      hipchatmsg[settings["hipchat"]["room"]].send('Sensu', "RESOLVED - [#{event_name}] - #{message}.", :color => 'green')
    else
      hipchatmsg[settings["hipchat"]["room"]].send('Sensu', "ALERT - [#{event_name}] - #{message}.", :color => 'red', :notify => true)
    end
  end

end
