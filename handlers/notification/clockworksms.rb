#!/usr/bin/env ruby
#
# Sensu Handler: clockworksms
#
# This handler send SMS via clockworksms API based on the severity of the check result.
#
# Requires: clockworksms gem
#
# Copyright 2014 Dejan Golja <dejan@golja.org>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'clockwork'
require 'timeout'

class ClockWorkSmsNotif < Sensu::Handler
  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def send_sms(to, from, content)
    content[157..content.length] = '...' if content.length > 160
    message = @api.messages.build
    message.to = to
    message.from = from
    message.content = content
    response = message.deliver

    # #YELLOW
    unless response.success # rubocop:disable GuardClause
      puts "#{response.error_code} - #{response.error_description}"
    end
  end

  def handle
    key = settings['clockworksms']['key']
    to = settings['clockworksms']['to']
    from = settings['clockworksms']['from'] || 'SENSU'

    fail 'Please define a valid SMS key' if key.nil?
    fail 'Please define a valid set of SMS recipients to use this handler' if to.nil? || !to.is_a?(Hash)

    message = @event['check']['notification'] || @event['check']['output']

    @api = Clockwork::API.new(key)

    to.each do |phone, severities|
      break unless severities.is_a?(Array)
      severities.map!(&:downcase)
      case @event['check']['status']
      when 0
        if severities.include?('ok')
          send_sms(phone, from, "OK-#{event_name} #{message}")
        end
      when 1
        if severities.include?('warning')
          send_sms(phone, from, "WARN-#{event_name} #{message}")
        end
      when 2
        if severities.include?('critical')
          send_sms(phone, from, "CRIT-#{event_name} #{message}")
        end
      end
    end
  end
end
