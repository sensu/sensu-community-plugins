#! /usr/bin/env ruby
#
#  check-es-cluster-status
#
# DESCRIPTION:
#   This plugin checks the ElasticSearch cluster status, using its API.
#   Works with ES 0.9x and ES 1.x
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2012 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class ESClusterStatus < Sensu::Plugin::Check::CLI
  option :host,
         description: 'Elasticsearch host',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'Elasticsearch port',
         short: '-p PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 9200

  option :master_only,
         description: 'Use master Elasticsearch server only',
         short: '-m',
         long: '--master-only',
         default: false

  option :timeout,
         description: 'Sets the connection timeout for REST client',
         short: '-t SECS',
         long: '--timeout SECS',
         proc: proc(&:to_i),
         default: 30

  def get_es_resource(resource)
    r = RestClient::Resource.new("http://#{config[:host]}:#{config[:port]}/#{resource}", timeout: config[:timeout])
    JSON.parse(r.get)
  rescue Errno::ECONNREFUSED
    critical 'Connection refused'
  rescue RestClient::RequestTimeout
    critical 'Connection timed out'
  rescue Errno::ECONNRESET
    critical 'Connection reset by peer'
  end

  def acquire_es_version
    info = get_es_resource('/')
    info['version']['number']
  end

  def master?
    if Gem::Version.new(acquire_es_version) >= Gem::Version.new('1.0.0')
      master = get_es_resource('_cluster/state/master_node')['master_node']
      local = get_es_resource('/_nodes/_local')
    else
      master = get_es_resource('/_cluster/state?filter_routing_table=true&filter_metadata=true&filter_indices=true')['master_node']
      local = get_es_resource('/_cluster/nodes/_local')
    end
    local['nodes'].keys.first == master
  end

  def acquire_status
    health = get_es_resource('/_cluster/health')
    health['status'].downcase
  end

  def run
    if !config[:master_only] || master?
      case acquire_status
      when 'green'
        ok 'Cluster is green'
      when 'yellow'
        warning 'Cluster is yellow'
      when 'red'
        critical 'Cluster is red'
      end
    else
      ok 'Not the master'
    end
  end
end
