#!/usr/bin/env ruby
#
# ElasticSearch Metrics Plugin
# ===
#
# This plugin uses the ES API to collect metrics, producing a JSON
# document which is outputted to STDOUT. An exit status of 0 indicates
# the plugin has successfully collected and produced.
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'json'

class ESClusterMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.elasticsearch.cluster"

  def get_es_resource(resource)
    begin
      r = RestClient::Resource.new("http://localhost:9200/#{resource}", :timeout => 45)
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    end
  end

  def is_master
    state = get_es_resource('/_cluster/state?filter_routing_table=true&filter_metadata=true&filter_indices=true')
    local = get_es_resource('/_cluster/nodes/_local')
    local['nodes'].keys.first == state['master_node']
  end

  def get_health
    health = get_es_resource('/_cluster/health').reject {|k, v| %w[cluster_name timed_out].include?(k)}
    health['status'] = ['red', 'yellow', 'green'].index(health['status'])
    health
  end

  def get_document_count
    document_count = get_es_resource('/_count?q=*:*')
    document_count['count']
  end

  def run
    if is_master
      get_health.each do |k, v|
        output(config[:scheme] + '.' + k, v)
      end
      output(config[:scheme] + '.document_count', get_document_count)
    end
    ok
  end

end
