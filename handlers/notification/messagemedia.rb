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
   @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
  end

  def should_send
    lower_limit = settings['messagemedia']['min_occurrences'].to_i * 10
    case
    when @event['occurrences'] < lower_limit
      return false
    when @event['occurrences'] >= lower_limit
      return true
    end
    return false
  end

  def handle
    Rumeme.configure do |config|
      config.username = settings['messagemedia']['username'] || 'xxx'
      config.password = settings['messagemedia']['password'] || 'yyy'
      config.use_message_id = true
      config.secure = true
      # config.allow_splitting = false
      # config.allow_long_messages = true
    end

    message = "#{action_to_string} - #{short_name}: #{@event['check']['notification']}"

    begin
      if should_send then
        timeout 10 do
          si = Rumeme::SmsInterface.new
          settings['messagemedia']['mobile_numbers'].each do |mobile_number|
            si.add_message :phone_number => mobile_number, :message => message
          end
          si.send_messages

          puts 'sms -- sent alert(s) for ' + short_name
        end
      else
        puts 'sms -- not enough occurrences (' + @event['occurrences'].to_s + ') to send alerts -- ' + short_name
      end
    rescue Timeout::Error
      puts 'sms -- timed out while attempting to ' + @event['action'] + ' an incident -- ' + short_name
    end
  end
end
