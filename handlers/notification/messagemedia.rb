#!/usr/bin/env ruby
#
# Sensu Handler: messagemedia
#
# This handler formats alerts as SMS messages and sends them off to pre-defined recipients using MessageMedia's SMS gateway
#
# Copyright 2012 Rafael Fonseca (http://twitter.com/rafaelmagu)
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'rumeme'
require 'timeout'

class MessageMedia < Sensu::Handler
  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    case @event['check']['status']
    when 0
      "RESOLVED"
    when 1
      "WARNING"
    when 2
      "CRITICAL"
    else
      "UNKNOWN"
    end
  end

  def handle
    Rumeme.configure do |config|
      config.username = settings['messagemedia']['username'] || 'xxx'
      config.password = settings['messagemedia']['password'] || 'yyy'
      config.use_message_id = true
      config.secure = true
    end

    message = "#{action_to_string} - #{short_name}: #{@event['check']['notification']}"

    begin
      timeout 10 do
        si = Rumeme::SmsInterface.new
        settings['messagemedia']['mobile_numbers'].each do |mobile_number|
          puts 'sms -- preparing alert(s) for ' + mobile_number
          begin
            si.add_message :phone_number => mobile_number, :message => message
          rescue ArgumentError
            puts 'sms -- failed sending alert(s) for ' + mobile_number
          end
        end
        si.send_messages

        puts 'sms -- sent alert(s) for ' + short_name
      end
    rescue Timeout::Error
      puts 'sms -- timed out while attempting to ' + @event['action'] + ' an incident -- ' + short_name
    end
  end
end
