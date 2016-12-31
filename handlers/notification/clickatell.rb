#!/usr/bin/env ruby
#
# Sensu Handler: clickatell
#
# This handler send SMS via clickatell API based on the severity of the check result.
# Based on the clockworksms handler by Dejan Golja
#
# Requires: clickatell gem
#
# Copyright 2014 Dejan Golja <dejan@golja.org>
# 
# Rewritten to work with clickatell by
# Alexander Holte-Davidsen <alexander@treg.io>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'clickatell'
require 'timeout'

class ClickaTellNotif < Sensu::Handler
  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    api_id = settings['clickatell']['api_id']
    to = settings['clickatell']['to']
    username = settings['clickatell']['username']
    password = settings['clickatell']['password'] 

    fail 'Please define a valid SMS api_id' if api_id.nil?
    fail 'Please define a valid set of SMS recipients to use this handler' if to.nil? || !to.is_a?(Hash)
    fail 'Please define a valid password' if password.nil?
    fail 'Please define a valid user' if user.nil?

    message = @event['check']['notification'] || @event['check']['output']

    api = Clickatell::API.authenticate(api_id, username, password)

    to.each do |phone, severities|
      break unless severities.is_a?(Array)
      severities.map!(&:downcase)
      case @event['check']['status']
      when 0
        if severities.include?('ok')
          api.send_message(phone, "OK-#{event_name} #{message}")
        end
      when 1
        if severities.include?('warning')
          api.send_message(phone, "WARN-#{event_name} #{message}")
        end
      when 2
        if severities.include?('critical')
          api.send_message(phone, "CRIT-#{event_name} #{message}")
        end
      end
    end
  end
end
