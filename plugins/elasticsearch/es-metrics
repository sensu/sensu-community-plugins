#!/usr/bin/env ruby
#
# ElasticSearch Metrics Plugin
# ===
#
# This plugin uses the ES API to collect metrics, producing a JSON
# document which is outputted to STDOUT. An exit status of 0 indicates
# the plugin has successfully collected and produced.
#
# Copyright 2011 Sonian, Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/metric/cli'
require 'rest-client'

class ESMetrics < Sensu::Plugin::Metric::CLI

  def delete_strings(hash)
    hash.each do |key, value|
      case value
      when String
        hash.delete(key)
      when Hash
        delete_strings(value)
      end
    end
  end

  def run
    begin
      stats = RestClient::Resource.new 'http://localhost:9200/_cluster/nodes/_local/stats', :timeout => 30
      stats = JSON.parse(stats.get)
      node = stats['nodes'].keys.first
    rescue Errno::ECONNREFUSED => e
      critical e
    rescue RestClient::RequestTimeout => e
      warning e
    end
    metrics = delete_strings(stats["nodes"][node])
    if metrics.empty?
      warning metrics
    else
      ok metrics
    end
  end
end
