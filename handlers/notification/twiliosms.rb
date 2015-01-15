#!/usr/bin/env ruby
#
# Sensu Handler: twilio
#
# This handler formats alerts as SMSes and sends them off to a pre-defined recipient.
#
# Copyright 2012 Panagiotis Papadomitsos <pj@ezgr.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'twilio-ruby'
require 'rest-client'
require 'json'

class TwilioSMS < Sensu::Handler
  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def handle
    account_sid = settings['twiliosms']['sid']
    auth_token = settings['twiliosms']['token']
    from_number = settings['twiliosms']['number']
    candidates = settings['twiliosms']['recipients']

    fail 'Please define a valid Twilio authentication set to use this handler' unless account_sid && auth_token && from_number
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

    twilio = Twilio::REST::Client.new(account_sid, auth_token)
    recipients.each do |recipient|
      begin
        twilio.account.messages.create(
          from: from_number,
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
