#!/usr/bin/env ruby
# encoding: UTF-8
# freesmsalert.rb
#
# DESCRIPTION:
#   Sensu handler for SMS alerting
#
#   This handler will send *FREE* sms alerts. It does so by sending an email
#   through a special carrier gateway address.
#
# OUTPUT:
#   No output unless there is an error.
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-handler
#   gem: mail
#   gem: timeout
#
# USAGE:
#   The carrier gateway mappings are specified in:
#     freesmsalert_carriers.json
#
#   Configure your recipients here (you need to know the phone # AND the carrier!):
#     freesmsalert_recipients.json
#
#   Then you can have different recipients mapped to different handlers by setting
#   up your handler config like this (substitute sms_alert_example for whatever):
#
#   {
#     "handlers": {
#       "sms_alert_example": {
#         "type": "pipe",
#         "command": "freesmsalert.rb sms_alert_example"
#       }
#     },
#     "sms_alert_example": {
#       "alert_recipients": [
#         "ghostbuster",
#         "ttutone"
#       ]
#     }
#   }
#
# NOTES:
#   Make sure you configure your SMTP settings correctly!
#
# LICENSE:
#   Author Mike Skovgaard   <mikesk@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
gem 'mail', '>= 2.5.0'
require 'mail'
require 'timeout'

##
# This class handles Sensu alerts through SMS messaging
#
class FreeSMSAlert < Sensu::Handler
  ##
  # This method sends the acutal email
  #
  def send_sms(user_id, mail_to, mail_from)
    mail_subject = "Alert:#{@event['check']['name']}"
    mail_body = <<-BODY.gsub(/^\s+/, '')
      #{@event['check']['output']}
    BODY
    timeout 10 do
      Mail.deliver do
        to mail_to
        from mail_from
        subject mail_subject
        body mail_body
      end
    end
  rescue Timeout::Error
    puts "#{@settings_key} -- timed out while attempting to send alert for #{user_id} to #{mail_to}"
  end

  ##
  # This methos is spawned when Sensu passes us an alert
  #
  # By default we'll use the free_sms_alert settings key. If you want different
  # people getting alerts for different plugins, then use a different
  # settings key in your handler config. Magic!
  #
  def handle
    @settings_key = 'free_sms_alert'
    @settings_key = ARGV[0] if ARGV.empty? == false
    smtp_address = settings['free_sms_alert']['smtp_address'] || 'localhost'
    smtp_port = settings['free_sms_alert']['smtp_port'] || '25'
    smtp_domain = settings['free_sms_alert']['smtp_domain'] || 'localhost.localdomain'
    mail_from = settings['free_sms_alert']['mail_from'] || 'sensu_alert@mydomain.com'
    Mail.defaults do
      delivery_method :smtp,
                      address: smtp_address,
                      port: smtp_port,
                      domain: smtp_domain,
                      openssl_verify_mode: 'none'
    end
    settings[@settings_key]['alert_recipients'].each do |user_id|
      mail_to = nil
      number = nil
      info = settings['free_sms_alert']['alert_recipient_mappings'][user_id]
      if info['carrier'] == 'email'
        number = info['number']
      else
        number = info['number'].gsub(/[^0-9]/, '')
      end
      settings['free_sms_alert']['carrier_portal'].each do |carrier, address|
        mail_to = address.gsub(/%number%/, number) if info['carrier'] == carrier
      end
      send_sms(user_id, mail_to, mail_from) if mail_to.nil? == false
    end
  end
end
