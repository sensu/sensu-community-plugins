#!/usr/bin/env ruby
#
# Sensu Handler: mailer-ses
#
# This handler formats alerts as mails and sends them off to a pre-defined recipient.
# Copyright 2013 github.com/foomatty
# Copyright 2012 Pal-Kristian Hamre (https://github.com/pkhamre | http://twitter.com/pkhamre)
#
# Requires aws-ses gem 'gem install aws-ses'
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'aws/ses'
require 'timeout'

class Mailer < Sensu::Handler
  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def handle
    params = {
      mail_to: settings['mailer-ses']['mail_to'],
      mail_from: settings['mailer-ses']['mail_from'],
      aws_access_key: settings['mailer-ses']['aws_access_key'],
      aws_secret_key: settings['mailer-ses']['aws_secret_key'],
      aws_ses_endpoint: settings['mailer-ses']['aws_ses_endpoint']
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

    ses = AWS::SES::Base.new(
      access_key_id: params[:aws_access_key],
      secret_access_key: params[:aws_secret_key],
      server: params[:aws_ses_endpoint]
    )

    begin
      timeout 10 do
        ses.send_email(
          to: params[:mail_to],
          source: params[:mail_from],
          subject: subject,
          text_body: body
        )

        puts 'mail -- sent alert for ' + short_name + ' to ' + params[:mail_to]
      end
    rescue Timeout::Error
      puts 'mail -- timed out while attempting to ' + @event['action'] + ' an incident -- ' + short_name
    end
  end
end
