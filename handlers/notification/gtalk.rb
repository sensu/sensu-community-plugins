#!/usr/bin/env ruby1.8
# Handler GTalk
# ===
#
#
# This is a simple Gtalk Handler script for Sensu, Add the GMil credentials and
# Recipient's Gmail id. Currently the message contains Event and Host
#
# Note:- Not compatible with Ruby Version > 1.9
#
#  Author Deepak Mohan Das   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems'
require 'sensu-handler'
require 'xmpp4r-simple'
require 'timeout'
include Jabber

class GTALK < Sensu::Handler

  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
  end

  def handle
    username = 'testmaster'
    password = 'secreto'
    to_username = 'deepakmdass88'
    body = <<-BODY.gsub(/^ {14}/, '')
            #{@event['check']['output']}
            Host: #{@event['client']['name']}
           BODY

    begin
      timeout 10 do
        puts "Connecting to jabber server.."
        jabber = Jabber::Simple.new(username+'@gmail.com', password)
        puts "Connected."
        jabber.deliver(to_username+"@gmail.com", "#{body}")
        sleep(10)
        puts "Alert successfully sent to #{to_username}"
      end
    rescue Timeout::Error
      puts "timed out while attempting to sent message"
    end
  end
end
