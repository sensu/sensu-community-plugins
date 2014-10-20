#!/usr/bin/env ruby
#
# Send metric data to your Logentries Account
# ===
#
# Copyright 2014 Stephen Hynes <sthynes8@gmail.com>
#
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'uri'
require 'net/http'

class LogentriesMetrics < Sensu::Handler

  @@uri
  # override filters from Sensu::Handler. not appropriate for metric handlers
  def filter
  end

  def handle
    log_token = settings['logentries']['log_token']
    if log_token
      @@uri = URI.parse("https://js.logentries.com/" + log_token)
      @event['check']['output'].split("\n").each do |line|
      name, value, timestamp = line.split(/\s+/)
      send_metric(name, value, timestamp)
    else
      puts "No log token found. Please enter your Log Token in logentries-metrics.json"
    end
  end

  def send_metric(name, value, timestamp)
    begin
      timeout(3) do
        http = Net::HTTP.new(@@uri.host, @@uri.port)
        header = {'Content-Type': 'text/json'}
        metric = {"event": { "timestamp": timestamp, "name": name, "value": value }}
        request = Net::HTTP::Post.new(@@uri.request_uri, header)
        response = http.request(request)
        print response
      end
    rescue Timeout::Error
      puts "Logentries -- timed out while sending metrics"
    rescue => error
      puts "Logentries -- failed to send metrics: #{error.message}"
      puts " #{error.backtrace.join("\n\t")}"
    end
  end
end
