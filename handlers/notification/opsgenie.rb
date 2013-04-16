#!/usr/bin/env ruby
#
# Opsgenie handler which creates and closes alerts. Based on the pagerduty
# handler.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require "net/https"
require "uri"
require "json"

class Opsgenie < Sensu::Handler


  def handle
    description = @event['notification'] || [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' : ')
    begin
      timeout(3) do
        response = case @event['action']
                   when 'create'
                     create_alert(description)
                   when 'resolve'
                     close_alert
                   end
        if response['code'] == 200
          puts 'opsgenie -- ' + @event['action'].capitalize + 'd incident -- ' + event_id
        else
          puts 'opsgenie -- failed to ' + @event['action'] + ' incident -- ' + event_id
        end
      end
    rescue Timeout::Error
      puts 'opsgenie -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + event_id
    end
  end

  def event_id
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def close_alert
    post_to_opsgenie(:close, {:alias => event_id})
  end

  def create_alert(description)
    post_to_opsgenie(:create, {:alias => event_id, :message => description})
  end

  def post_to_opsgenie(action = :create, params = {})

    params["customerKey"] = settings["opsgenie"]["customerKey"]
    params["recipients"]  = settings["opsgenie"]["recipients"]

    uripath = (action == :create) ? "" : "close"

    uri = URI.parse("https://api.opsgenie.com/v1/json/alert/#{uripath}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.request_uri,initheader = {'Content-Type' =>'application/json'})
    request.body = params.to_json
    response = http.request(request)
    JSON.parse(response.body)

  end

end
