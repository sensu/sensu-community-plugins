#!/usr/bin/env ruby1.8
# Handler GTalk
# ===
#
#
# This is a simple Gtalk Handler script for Sensu, Add the GMil credentials and
# Recipient's Gmail id. Currently the message contains Event and Host
#
# Notes:
#   - for Ruby Version > 1.9 compatibility you need to install "xmpp4r-simple-19" gem
#   - if sender is registered for Google Hangouts he can't send message. Maybe it is a
#     problem with XMPP and Hangouts. In this case you need to register a new gmail
#     account and don't register it for Hangouts
#   - If client is registered for Hangouts he will not get the message. Client has to
#     change IM settings to Old version in Gmail page (left side)
#
#  Author Deepak Mohan Das   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'xmpp4r-simple'
require 'timeout'
include Jabber

# Sensu handler for Google Talk
class GTALK < Sensu::Handler

  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
  end

  def handle
    body = <<-BODY.gsub(/^ {14}/, '')
            #{@event['check']['output']}
            Host: #{@event['client']['name']}
           BODY

    begin
      timeout 10 do
        puts "gtalk -- Connecting to jabber server with user #{settings["gtalk"]["mail"]}"
        jabber = Jabber::Simple.new(settings["gtalk"]["mail"], settings["gtalk"]["password"])
        puts "gtalk -- Connected"
        settings["gtalk"]["recipients"].each do |rcp|
          puts "gtalk -- Sending alert to #{rcp}"
          jabber.deliver(rcp, "#{body}")
        end
        sleep(5)
        puts "gtalk -- Alert successfully sent to recipients"
      end
    rescue Timeout::Error
      puts "gtalk -- timed out while attempting to sent message"
    end
  end
end
