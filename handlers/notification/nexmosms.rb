#!/usr/bin/env ruby
#
# Sensu Handler: nexmo
#
# This handler formats alerts as SMSes and sends them off to a pre-defined recipient.
#
# Copyright 2015 Abdulrahim Umar <harsh001(at)gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'nexmo'
require 'rest-client'
require 'json'

class NexmoSMS < Sensu::Handler
  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def handle
    api_secret = settings['nexmosms']['api_secret']
    api_key = settings['nexmosms']['api_key']
    sender_id = settings['nexmosms']['sender_id']
    candidates = settings['nexmosms']['recipients']

    fail 'Please define a valid nexmo authentication set to use this handler' unless api_secret && api_key && sender_id
    fail 'Please define a valid set of SMS recipients to use this handler' if candidates.nil? || candidates.empty?

    recipients = []
    # #YELLOW
    candidates.each do |mobile, candidate|  # rubocop:disable Style/Next
      if ((candidate['sensu_roles'].include?('all')) ||
          ((candidate['sensu_roles'] & @event['check']['subscribers']).size > 0) ||
          (candidate['sensu_checks'].include?(@event['check']['name']))) &&
          (candidate['sensu_level'] >= @event['check']['status'])
        recipients << mobile
      end
    end

    message = "Sensu #{action_to_string}: #{short_name} (#{@event['client']['address']}) #{@event['check']['output']}"
    message[157..message.length] = '...' if message.length > 160

    nexmo = Nexmo::Client.new(key: api_key, secret: api_secret)
    recipients.each do |recipient|
      begin
        nexmo.send.message(
          from: sender_id,
          to: recipient,
          body: message
        )
        puts "Notified #{recipient} for #{action_to_string}"
      rescue => e
        puts "Failure detected while using Twilio to notify on event: #{e.message}"
      end
    end
  end
end
