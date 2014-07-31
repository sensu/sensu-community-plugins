#!/usr/bin/env ruby
# Handler RT
# ===
#
# This is a simple Handler script for Sensu which will create
# tickets in Request Tracker for each event
#
# Note :- Replace user, pass, requestor, server, queue variables
#     to suit to your RT
#
#  Author Deepak Mohan Das   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-handler'
require 'net/http'
require 'timeout'

class RT < Sensu::Handler
  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
   @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
  end

  def handle
    user = 'rt_user'
    pass = 'rt_pass'
    requestor = 'rt_user@example.com'
    server = 'http://localhost/'
    queue = 'queue'
    uri = URI("#{server}/REST/1.0/ticket/new")
    stat = "#{@event['check']['output']}".chomp
    body = <<-BODY.gsub(/^ {14}/, '')
      #{stat}
            Host: #{@event['client']['name']}
            Timestamp: #{Time.at(@event['check']['issued'])}
            Address:  #{@event['client']['address']}
            Check Name:  #{@event['check']['name']}
            Command:  #{@event['check']['command']}
            Status:  #{@event['check']['status']}
            Occurrences:  #{@event['occurrences']}
           BODY
    subject = "#{action_to_string} - #{short_name}: #{@event['check']['notification']}"
    content = "id: ticket/new\nRequestor: #{requestor}\nSubject: #{subject}\nStatus: new\nText: #{body} ticket\nQueue: #{queue}"
    begin
      timeout 10 do
        puts "Connecting to Request tracker"
        response = Net::HTTP.post_form(uri, {'user' => user, 'pass' => pass, 'content' => content})
        puts "Response - #{response}"
      end
    rescue Timeout::Error
      puts "CRITICAL --- Timed out while attempting to create ticket in RT"
    rescue Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      puts "Critical --- HTTP Connection error #{e.message}"
    end
  end
end
