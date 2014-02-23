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
    apiversion = settings["hipchat"]["apiversion"] || 'v1'
    hipchatmsg = HipChat::Client.new(settings["hipchat"]["apikey"], :api_version => apiversion)
    room = settings["hipchat"]["room"]
    from = settings["hipchat"]["from"] || 'Sensu'

    message = @event['check']['notification'] || @event['check']['output']

    # If the playbook attribute exists and is a URL, "[<a href='url'>playbook</a>]" will be output.
    # To control the link name, set the playbook value to the HTML output you would like.
    if @event['check']['playbook']
      begin
        uri = URI.parse(@event['check']['playbook'])
        if %w( http https ).include?(uri.scheme)
          message << "  [<a href='#{@event['check']['playbook']}'>Playbook</a>]"
        else
          message << "  Playbook:  #{@event['check']['playbook']}"
        end
      rescue
        message << "  Playbook:  #{@event['check']['playbook']}"
      end
    end

    begin
      timeout(3) do
        if @event['action'].eql?("resolve")
          hipchatmsg[room].send(from, "RESOLVED - [#{event_name}] - #{message}.", :color => 'green')
        else
          hipchatmsg[room].send(from, "ALERT - [#{event_name}] - #{message}.", :color => @event['check']['status'] == 1 ? 'yellow' : 'red', :notify => true)
        end
      end
    rescue Timeout::Error
      puts "hipchat -- timed out while attempting to message #{room}"
    end
  end

end
