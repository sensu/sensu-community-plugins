#!/usr/bin/env ruby
#
# Copyright 2013 Katherine Daniels (kd@gc.io)
#
# Depends on dogapi gem
# gem install dogapi
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'dogapi'

class DatadogMetrics < Sensu::Handler
  # override filters from Sensu::Handler. not appropriate for metric handlers
  def filter
  end

  def handle
    @dog = Dogapi::Client.new(settings['datadog']['api_key'], settings['datadog']['app_key'])

    @event['check']['output'].split("\n").each do |line|
      name, value, timestamp = line.split(/\s+/)
      emit_metric(name, value, timestamp)
    end
  end

  def emit_metric(name, value, _timestamp)
    timeout(3) do
      @dog.emit_point(name, value, host: @event['client']['name'])
    end
  rescue Timeout::Error
    puts 'datadog -- timed out while sending metrics'
  rescue => error
    puts "datadog -- failed to send metrics: #{error.message}"
    puts " #{error.backtrace.join("\n\t")}"
  end
end
