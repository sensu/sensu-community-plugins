#!/usr/bin/env ruby
#
# Sensu Handler: pushover
## Updates 12/19/2014 - Added rudimentary 'occurrences' and 'refresh' key support.
## by Jordan Anderson (https://github.com/aqtrans)
#
# This handler formats alerts and sends them off to a the pushover.net service.
#
# Copyright 2012 David Wooldridge (https://github.com/z0mbix | http://twitter.com/z0mbix)
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'net/https'
require 'sensu-handler'
require 'timeout'

class Pushover < Sensu::Handler
  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    po_occurrences = @event['occurrences'].to_i
    po_refresh = @event['check']['refresh'].to_i
    # if @event['occurrences'] == 1 || @event['occurrences'] % @event['check']['refresh'] == 0
    if po_occurrences == 1 || po_occurrences % po_refresh == 0
      pushover
    else
      puts 'pushover -- occurrences:' + po_occurrences.to_s + ' refresh:' + po_refresh.to_s + ' on ' + @event['check']['name']
    end
  end

  def pushover
      incident_key = @event['client']['name'] + '/' + @event['check']['name']
      params = {
        title: event_name,
        user: settings['pushover']['userkey'],
        token: settings['pushover']['token'],
        message: @event['check']['output']
      }
      begin
        timeout(3) do
          apiurl = 'https://api.pushover.net/1/messages.json'
          url = URI.parse(apiurl)
          req = Net::HTTP::Post.new(url.path)
          req.set_form_data(params)
          res = Net::HTTP.new(url.host, url.port)
          res.use_ssl = true
          res.verify_mode = OpenSSL::SSL::VERIFY_PEER
          res.start { |http| http.request(req) }
          puts res
        end
      rescue Timeout::Error
        puts 'pushover -- timed out while attempting to ' + @event['action'] + ' incident -- ' + incident_key
      end
  end
end
