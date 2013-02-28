#!/usr/bin/env ruby
#
# Sensu Handler: mailer
#
# This handler formats alerts as mails and sends them off to a pre-defined recipient.
#
# Copyright 2012 Pal-Kristian Hamre (https://github.com/pkhamre | http://twitter.com/pkhamre)
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
gem 'mail', '~> 2.4.0'
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
    smtp_address = settings['mailer']['smtp_address'] || 'localhost'
    smtp_port = settings['mailer']['smtp_port'] || '25'
    smtp_domain = settings['mailer']['smtp_domain'] || 'localhost.localdomain'
    
    params = {
      :mail_to   => settings['mailer']['mail_to'],
      :mail_from => settings['mailer']['mail_from'],
      :smtp_addr => smtp_address,
      :smtp_port => smtp_port,
      :smtp_domain => smtp_domain
    }

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
      delivery_method :smtp, {
        :address => params[:smtp_addr],
        :port    => params[:smtp_port],
        :domain  => params[:smtp_domain],
        :openssl_verify_mode => 'none'
      }
    end

    begin
      timeout 10 do
        Mail.deliver do
          to      params[:mail_to]
          from    params[:mail_from]
          subject subject
          body    body
        end

        puts 'mail -- sent alert for ' + short_name + ' to ' + params[:mail_to]
      end
    rescue Timeout::Error
      puts 'mail -- timed out while attempting to ' + @event['action'] + ' an incident -- ' + short_name
    end
  end
end
