#!/usr/bin/env ruby
# Copyright 2011 Sonian Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ElasticSearch Metrics Plugin
# ===
#
# This plugin uses the ES API to collect metrics, producing a JSON
# document which is outputted to STDOUT. An exit status of 0 indicates
# the plugin has successfully collected and produced.
#

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
