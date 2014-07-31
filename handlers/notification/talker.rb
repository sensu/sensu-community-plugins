#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'
require 'uri'

# required settings:
#  room
#  token
#  account (if using talkerapp.com)
#  host (if not using talkerapp.com)
#
# optional settings:
#  ssl (default true)
#  port (default 80 or 443)
#  host (default account.talkerapp.com)

class TalkerNotif < Sensu::Handler

  def host
    settings["talker"]["host"] || "#{settings["talker"]["account"]}.talkerapp.com"
  end

  def port
    settings["talker"]["port"] || ssl ? 443 : 80
  end

  def ssl
    settings["talker"]["ssl"].nil? ? true : settings["talker"]["ssl"]
  end

  def room_uri
    protocol = ssl ? "https" : "http"
    URI.parse("#{protocol}://#{host}:#{port}/rooms/#{settings["talker"]["room"]}/messages.json")
  end

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    http = Net::HTTP.new(room_uri.host, room_uri.port)

    http.use_ssl = true if ssl
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(room_uri.request_uri)
    request['X-Talker-Token'] = settings["talker"]["token"]

    if @event['action'].eql?("resolve")
      message = "Sensu RESOLVED - [#{event_name}] - #{@event['check']['notification']}"
    else
      message = "Sensu ALERT - [#{event_name}] - #{@event['check']['notification']}"
    end

    request.content_type = 'application/json'
    request.body = JSON.dump(:message => message)
    http.request(request)
  end

end
