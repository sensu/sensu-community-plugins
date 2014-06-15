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
gem 'mail', '~> 2.5.4'
require 'mail'
require 'timeout'

# patch to fix Exim delivery_method: https://github.com/mikel/mail/pull/546
module ::Mail
  class Exim < Sendmail
    def self.call(path, arguments, destinations, encoded_message)
      popen "#{path} #{arguments}" do |io|
        io.puts encoded_message.to_lf
        io.flush
      end
    end
  end
end

class Mailer < Sensu::Handler
  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
   @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
  end

  def build_mail_to_list
    mail_to = settings['mailer']['mail_to']
    if settings['mailer'].has_key?('subscriptions')
      @event['check']['subscribers'].each do |sub|
        if settings['mailer']['subscriptions'].has_key?(sub)
          mail_to << ", #{settings['mailer']['subscriptions'][sub]['mail_to']}"
        end
      end
    end
    mail_to
  end

  def handle
    admin_gui = settings['mailer']['admin_gui'] || 'http://localhost:8080/'
    mail_to = build_mail_to_list
    mail_from =  settings['mailer']['mail_from']

    delivery_method = settings['mailer']['delivery_method'] || 'smtp'
    smtp_address = settings['mailer']['smtp_address'] || 'localhost'
    smtp_port = settings['mailer']['smtp_port'] || '25'
    smtp_domain = settings['mailer']['smtp_domain'] || 'localhost.localdomain'

    smtp_username = settings['mailer']['smtp_username'] || nil
    smtp_password = settings['mailer']['smtp_password'] || nil
    smtp_authentication = settings['mailer']['smtp_authentication'] || :plain
    smtp_enable_starttls_auto = settings['mailer']['smtp_enable_starttls_auto'] == "false" ? false : true

    playbook = "Playbook:  #{@event['check']['playbook']}" if @event['check']['playbook']
    body = <<-BODY.gsub(/^\s+/, '')
            #{@event['check']['output']}
            Admin GUI: #{admin_gui}
            Host: #{@event['client']['name']}
            Timestamp: #{Time.at(@event['check']['issued'])}
            Address:  #{@event['client']['address']}
            Check Name:  #{@event['check']['name']}
            Command:  #{@event['check']['command']}
            Status:  #{@event['check']['status']}
            Occurrences:  #{@event['occurrences']}
            #{playbook}
          BODY
    subject = "#{action_to_string} - #{short_name}: #{@event['check']['notification']}"

    Mail.defaults do
      delivery_options = {
        :address    => smtp_address,
        :port       => smtp_port,
        :domain     => smtp_domain,
        :openssl_verify_mode => 'none',
        :enable_starttls_auto => smtp_enable_starttls_auto
      }

      unless smtp_username.nil?
        auth_options = {
          :user_name        => smtp_username,
          :password         => smtp_password,
          :authentication   => smtp_authentication
        }
        delivery_options.merge! auth_options
      end

      delivery_method delivery_method.intern, delivery_options
    end

    begin
      timeout 10 do
        Mail.deliver do
          to      mail_to
          from    mail_from
          subject subject
          body    body
        end

        puts 'mail -- sent alert for ' + short_name + ' to ' + mail_to.to_s
      end
    rescue Timeout::Error
      puts 'mail -- timed out while attempting to ' + @event['action'] + ' an incident -- ' + short_name
    end
  end
end
