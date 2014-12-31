#!/usr/bin/env ruby
#
# Copyright 2013 Nick Stielau
#
# This handler will send graphite-style metrics to statuspage.io, for
# displaying public metrics.  Note, this forks and is not meant for
# high-throughput.  Rather, it is meant for high-value, low-throughput
# metrics for display on status page.
#
# Depends on httpary gem
#   gem install httparty
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'httparty'

class StatusPageIOMetrics < Sensu::Handler
  # override filters from Sensu::Handler. not appropriate for metric handlers
  def filter; end

  def send_metric(value, timestamp, metric_id)
    # puts "Sending #{value} #{timestamp} #{metric_id}"
    timeout(3) do
      HTTParty.post(
        "https://api.statuspage.io/v1/pages/#{@page_id}/metrics/#{metric_id}/data.json",
        headers: { 'Authorization' => "OAuth #{@api_key}" },
        body: {
          data: {
            timestamp: timestamp,
            value: value.to_f
          }
        }
      )
    end
  rescue Timeout::Error
    puts 'statuspageio -- timed out while sending metrics'
  rescue => error
    puts "statuspageio -- failed to send metric #{metric_id} : #{error}"
  end

  def handle
    # Grab page_id and api_key from dashboard
    @api_key = settings['handlers']['statuspageio_metrics']['api_key']
    @page_id = settings['handlers']['statuspageio_metrics']['page_id']

    # Get a dict of metric_from_output => metric_ids
    # This allows the re-use of standard metrics plugins that can be mapped to
    # statuspage io metrics
    @metrics = settings['handlers']['statuspageio_metrics']['metrics'] || {}

    # Split graphite-style metrics
    @event['check']['output'].split(/\n/).each do |m|
      metric, value, timestamp = m.split
      # Get the metric ID from the check, or from the global mapping
      metric_id = @event['check']['statuspageio_metric_id'] || @metrics[metric]
      send_metric(value, timestamp, metric_id) if metric_id
    end
  end
end
