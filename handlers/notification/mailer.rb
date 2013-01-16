#!/usr/bin/env ruby
#
# Sensu Handler: mailer
#
# This handler formats alerts as mails and sends them off to a pre-defined recipient.
#
# Copyright 2012 Pål-Kristian Hamre (https://github.com/pkhamre | http://twitter.com/pkhamre)
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'mail'
require 'timeout'

class Mailer < Sensu::Handler
  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
   @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
  end

  def handle

    settings['mailer'] ||= {}
    puts "settings is %s" % settings.inspect
    puts "settings[mailer] is %s" % settings['mailer']

    defaults = {
      :address => 'localhost',
      :port => 25
    }

    # merge defaults and convert keys to symbols
    params = defaults.merge(settings['mailer'].inject({}) { |result, (k, v)| result[k.to_sym] = v; result })

    puts "params is %s" % params.inspect

    # for backwards-compatibility
    mappings = {
      :smtp_address => :address,
      :smtp_port => :port,
      :smtp_domain => :domain,
      :mail_to => :to,
      :mail_from => :from
    }

    params = mappings.inject({}) do |result, (k, v)|
      result[v] = params[k] if params[k]
      params.merge(result)
    end

    params.delete_if { |k, _| mappings.has_key? k }

    bail 'Missing setting: "to"' unless params[:to]
    bail 'Missing setting: "from"' unless params[:from]

    body = <<-BODY.gsub(/^ {14}/, '')
            #{@event['check']['output']}
            Host: #{@event['client']['name']}
            Timestamp: #{Time.at(@event['check']['issued'])}
            Address:  #{@event['client']['address']}
            Check Name:  #{@event['check']['name']}
            Command:  #{@event['check']['command']}
            Status:  #{@event['check']['status']}
            Occurrences:  #{@event['occurrences']}
          BODY

    subject = "#{action_to_string} - #{short_name}: #{@event['check']['notification']}"

    Mail.defaults do
      delivery_method :smtp, params
    end

    begin
      timeout 10 do
        Mail.deliver do
          to params[:to]
          from params[:from]
          subject subject
          body body
        end

        puts 'mail -- sent alert for ' + short_name + ' to ' + params[:to]
      end
    rescue Timeout::Error
      puts 'mail -- timed out while attempting to ' + @event['action'] + ' an incident -- ' + short_name
    end
  end
end
