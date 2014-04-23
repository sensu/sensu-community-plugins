#!/usr/bin/env ruby
#
# Checks ElasticSearch cluster status
# ===
#
# DESCRIPTION:
#   This plugin checks the ElasticSearch cluster status, using its API.
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

class ESClusterStatus < Sensu::Plugin::Check::CLI

  option :server,
    :description => 'Elasticsearch server',
    :short => '-s SERVER',
    :long => '--server SERVER',
    :default => 'localhost'

  def get_es_resource(resource)
    begin
      r = RestClient::Resource.new("http://#{config[:server]}:9200/#{resource}", :timeout => 45)
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    end
  end

  def get_version
    system = get_es_resource('/')
    system['version']['number']
  end

  def pre_one_point_oh?
    version = get_version
    cur_version = version.split('.')
    min_version = ["1","0","0"]

    length = [cur_version.length, min_version.length].max - 1
    cur_version.fill(0, cur_version.length..length)
    min_version.fill(0, min_version.length..length)

    (0..length).each { |i|
       val = cur_version[i].to_i - min_version[i].to_i
       return val < 0 if val != 0
    }

    false
  end

  # API endpoint changed in 1.0.
  def local_uri
    return "/_cluster/nodes/_local" if pre_one_point_oh?
    return "/_nodes/_local"
  end

  def is_master
    state = get_es_resource('/_cluster/state?filter_routing_table=true&filter_metadata=true&filter_indices=true')
    local = get_es_resource(local_uri)
    local['nodes'].keys.first == state['master_node']
  end

  def get_status
    health = get_es_resource('/_cluster/health')
    health['status'].downcase
  end

  def run
    if is_master
      case get_status
      when 'green'
        ok "Cluster is green"
      when 'yellow'
        warning "Cluster is yellow"
      when 'red'
        critical "Cluster is red"
      end
    else
      ok 'Not the master'
    end
  end

end
