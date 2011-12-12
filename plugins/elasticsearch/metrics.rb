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

require 'rubygems'
require 'rest-client'
require 'json'

class ESMetrics
  def initialize
    get_metrics
  end

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

  def get_metrics
    begin
      stats = RestClient::Resource.new 'http://localhost:9200/_cluster/nodes/_local/stats', :timeout => 30
      stats = JSON.parse(stats.get)
      node = stats['nodes'].keys.first
    rescue Errno::ECONNREFUSED
      exit 2
    rescue RestClient::RequestTimeout
      exit 1
    end
    @metrics = delete_strings(stats["nodes"][node])
    unless @metrics.empty?
      @metrics.merge!({:timestamp => Time.now.to_i})
    else
      exit 1
    end
  end

  def output
    puts @metrics.to_json
  end
end

metrics = ESMetrics.new
metrics.output
