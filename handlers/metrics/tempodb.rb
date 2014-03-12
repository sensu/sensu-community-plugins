#!/usr/bin/env ruby
#
# Sensu Handler: tempodb
#
# Copyright 2012 TempoDB, Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# Dependencies:
#   tempodb gem: gem install tempodb
#
# Compatible checks should generate output in the format:
#   metric.path.one value timestamp\n
#   metric.path.two value timestamp\n

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'tempodb'

class TempoDBSensu < Sensu::Handler

  def handle
    client = TempoDB::Client.new(
      settings['tempodb']['api_key'],
      settings['tempodb']['api_secret']
    )

    metrics = @event['check']['output']
    time = Time.now
    data = []

    # loop through metrics, separated by \n, pull out each metric and add to data array
    metrics.split("\n").each do |metric|
      m = metric.split

      # Should match format metric.path.two value timestamp
      next unless m.count == 3

      key = m[0]
      v = m[1].to_f
      data.push({ 'key' => key, 'v' => v })
    end

    begin
      timeout(3) do
        client.write_bulk(time, data)
      end
    rescue Timeout::Error
      puts "tempodb -- timed out while sending bulk write"
    rescue => error
      puts "tempodb -- failed to send bulk write : #{error}"
    end
  end
end
