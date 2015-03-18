#! /usr/bin/env ruby
# encoding: UTF-8
#
#   es-node-metrics
#
# DESCRIPTION:
#   This plugin uses the ES API to collect metrics, producing a JSON
#   document which is outputted to STDOUT. An exit status of 0 indicates
#   the plugin has successfully collected and produced.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2011 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'json'

class ESMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to queue_name.metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.elasticsearch"

  option :host,
         description: 'Elasticsearch server host.',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'Elasticsearch port',
         short: '-p PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 9200

  def get_es_resource(resource)
    r = RestClient::Resource.new("http://#{config[:host]}:#{config[:port]}/#{resource}", timeout: config[:timeout])
    JSON.parse(r.get)
  rescue Errno::ECONNREFUSED
    warning 'Connection refused'
  rescue RestClient::RequestTimeout
    warning 'Connection timed out'
  end

  def acquire_es_version
    info = get_es_resource('/')
    info['version']['number']
  end

  def run
    if Gem::Version.new(acquire_es_version) >= Gem::Version.new('1.0.0')
      ln = RestClient::Resource.new "http://#{config[:host]}:#{config[:port]}/_nodes/_local", timeout: 30
      stats = RestClient::Resource.new "http://#{config[:host]}:#{config[:port]}/_nodes/stats", timeout: 30
    else
      ln = RestClient::Resource.new "http://#{config[:host]}:#{config[:port]}/_cluster/nodes/_local", timeout: 30
      stats = RestClient::Resource.new "http://#{config[:host]}:#{config[:port]}/_cluster/nodes/_local/stats", timeout: 30
    end
    ln = JSON.parse(ln.get)
    stats = JSON.parse(stats.get)
    timestamp = Time.now.to_i
    node = stats['nodes'].values.first
    node['jvm']['mem']['heap_max_in_bytes'] = ln['nodes'].values.first['jvm']['mem']['heap_max_in_bytes']
    metrics = {}
    metrics['os.load_average'] = node['os']['load_average'][0]
    metrics['os.mem.free_in_bytes'] = node['os']['mem']['free_in_bytes']
    metrics['process.mem.resident_in_bytes'] = node['process']['mem']['resident_in_bytes']
    metrics['jvm.mem.heap_used_in_bytes'] = node['jvm']['mem']['heap_used_in_bytes']
    metrics['jvm.mem.non_heap_used_in_bytes'] = node['jvm']['mem']['non_heap_used_in_bytes']
    if Gem::Version.new(acquire_es_version) >= Gem::Version.new('1.0.0')
      metrics['jvm.gc.collectors.young.collection_time'] = node['jvm']['gc']['collectors']['young']['collection_time_in_millis']
      metrics['jvm.gc.collectors.old.collection_time'] = node['jvm']['gc']['collectors']['old']['collection_time_in_millis']
    else
      metrics['jvm.gc.collection_time_in_millis'] = node['jvm']['gc']['collection_time_in_millis']
    end
    metrics.each do |k, v|
      output([config[:scheme], k].join('.'), v, timestamp)
    end
    ok
  end
end
