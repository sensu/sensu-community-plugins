#!/usr/bin/env ruby
#
# Checks ElasticSearch heap usage based on percent used
# ===
#
# DESCRIPTION:
#   This plugin checks ElasticSearch's Java heap usage using its API.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   rest-client Ruby gem
#
# Copyright 2014 Panagiotis Papadomitsos <pj@ezgr.net>
# Original code Copyright 2012 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class ESHeapPct < Sensu::Plugin::Check::CLI

  option :host,
    :description => 'Elasticsearch host',
    :short => '-h HOST',
    :long => '--host HOST',
    :default => 'localhost'

  option :port,
    :description => 'Elasticsearch port',
    :short => '-p PORT',
    :long => '--port PORT',
    :proc => proc {|a| a.to_i },
    :default => 9200

  option :warn,
    :short => '-w N',
    :long => '--warn N',
    :description => 'Heap percent used WARNING threshold',
    :proc => proc {|a| a.to_i },
    :default => 90

  option :timeout,
    :description => 'Sets the connection timeout for REST client',
    :short => '-t SECS',
    :long => '--timeout SECS',
    :proc => proc {|a| a.to_i },
    :default => 30

  option :crit,
    :short => '-c N',
    :long => '--crit N',
    :description => 'Heap percent used CRITICAL threshold',
    :proc => proc {|a| a.to_i },
    :default => 95

  def get_es_version
    info = get_es_resource('/')
    info['version']['number']
  end

  def get_es_resource(resource)
    begin
      r = RestClient::Resource.new("http://#{config[:host]}:#{config[:port]}/#{resource}", :timeout => config[:timeout])
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    rescue JSON::ParserError
      warning 'Elasticsearch API returned invalid JSON'
    end
  end

  def get_heap_data
    if Gem::Version.new(get_es_version) >= Gem::Version.new('1.0.0')
      stats = get_es_resource('_nodes/_local/stats?jvm=true')
      node = stats['nodes'].keys.first
    else
      stats = get_es_resource('_cluster/nodes/_local/stats?jvm=true')
      node = stats['nodes'].keys.first
    end
    begin
      return stats['nodes'][node]['jvm']['mem']['heap_used_in_bytes'], stats['nodes'][node]['jvm']['mem']['heap_max_in_bytes']
    rescue
      warning 'Failed to obtain heap used in bytes'
    end
  end

  def run
    heap_used, heap_max = get_heap_data
    heap_used_ratio = ((100 * heap_used) / heap_max).to_i
    message "Heap used in bytes #{heap_used} (#{heap_used_ratio}% full)"
    if heap_used_ratio >= config[:crit]
      critical
    elsif heap_used_ratio >= config[:warn]
      warning
    else
      ok
    end
  end

end
