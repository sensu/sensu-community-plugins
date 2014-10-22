#!/usr/bin/env ruby
#
# Sensu Handler: clickatell

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'rest-client'
require 'clickatell'
require 'json'

class ClickatellSMS < Sensu::Handler

  def short_name
      @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
  end

  def handle
    clickatell_api_id = settings['clickatell']['api_id']
    clickatell_api_username = settings['clickatell']['api_username']
    clickatell_api_password = settings['clickatell']['api_password']
    clickatell_api_from = settings['clickatell']['api_from']
    candidates = settings['clickatell']['recipients']

    raise 'Please define all necesarry Clickatell API settings to use this handler' unless (clickatell_api_id && clickatell_api_username && clickatell_api_password && clickatell_api_from)
    raise 'Please define a valid set of SMS recipients to use this handler' if (candidates.nil? || candidates.empty?)

    recipients = []
    candidates.each do |mobile, candidate|
      if (((candidate['sensu_roles'].include?('all')) ||
          ((candidate['sensu_roles'] & @event['check']['subscribers']).size > 0) ||
          (candidate['sensu_checks'].include?(@event['check']['name']))) &&
          (candidate['sensu_level'] >= @event['check']['status']))
        recipients << mobile
      end
    end

    message = "Sensu #{action_to_string}: #{short_name} (#{@event['client']['address']}) #{@event['check']['output']}"
    message[157..message.length] = '...' if message.length > 160

    clickatell = Clickatell::API.authenticate(clickatell_api_id, clickatell_api_username, clickatell_api_password)
    recipients.each do |recipient|
      begin
        options = {}
        options[:from] = clickatell_api_from
        response = clickatell.send_message(recipient, message, options)
        puts "Notified #{recipient} for #{action_to_string} with message ID: #{response.to_s}"
      rescue Exception => e
        puts "Failure detected while using Clickatell to notify on event: #{e.message}"
      end
    end
  end
end
