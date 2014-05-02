#!/usr/bin/env ruby
#
# Checks ElasticSearch heap usage
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
# Copyright 2012 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class ESHeap < Sensu::Plugin::Check::CLI

  option :server,
    :description => 'Elasticsearch server',
    :short => '-s SERVER',
    :long => '--server SERVER',
    :default => 'localhost'

  option :warn,
    :short => '-w N',
    :long => '--warn N',
    :description => 'Heap used in bytes WARNING threshold',
    :proc => proc {|a| a.to_i },
    :default => 0

  option :crit,
    :short => '-c N',
    :long => '--crit N',
    :description => 'Heap used in bytes CRITICAL threshold',
    :proc => proc {|a| a.to_i },
    :default => 0

  option :port,
    :short => '-p N',
    :long => '--port N',
    :description => "Specify port used",
    :proc => proc {|a| a.to_i },
    :default => 9200

  def get_es_version
    info = get_es_resource('/')
    info['version']['number']
  end

  def get_es_resource(resource)
    begin
      r = RestClient::Resource.new("http://#{config[:server]}:#{config[:port]}/#{resource}", :timeout => 45)
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    rescue JSON::ParserError
      warning 'Elasticsearch API returned invalid JSON'
    end
  end

  def get_heap_used
    if Gem::Version.new(get_es_version) >= Gem::Version.new('1.0.0')
      stats = get_es_resource('_nodes/_local/stats?jvm=true')
      node = stats['nodes'].keys.first
    else
      stats = get_es_resource('_cluster/nodes/_local/stats?jvm=true')
      node = stats['nodes'].keys.first
    end
    begin
      stats['nodes'][node]['jvm']['mem']['heap_used_in_bytes']
    rescue
      warning 'Failed to obtain heap used in bytes'
    end
  end

  def run
    heap_used = get_heap_used
    message "Heap used in bytes #{heap_used}"
    if heap_used >= config[:crit]
      critical
    elsif heap_used >= config[:warn]
      warning
    else
      ok
    end
  end

end
