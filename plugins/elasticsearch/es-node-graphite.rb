#!/usr/bin/env ruby
#
# Metrics from ElasticSearch Node
# ===
#
# DESCRIPTION:
#   This check creates node metrics from the elasticsearch API 
#
# OUTPUT:
#   plain-text / graphite
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   rest-client Ruby gem
#   json Ruby gem
#
# 2012/12 - Modified by Zach Dunn @SillySophist http://github.com/zadunn
# To add more metrics, and correct for new versins of ES. Tested on
# ES Version 0.19.8
#
# Copyright 2012 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'json'

class ESMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to queue_name.metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.elasticsearch"

  def run
    ln = RestClient::Resource.new 'http://localhost:9200/_cluster/nodes/_local', :timeout => 30
    stats = RestClient::Resource.new 'http://localhost:9200/_cluster/nodes/_local/stats?clear=true&indices=true&os=true&process=true&jvm=true&network=true&transport=true&http=true&fs=true&thread_pool=true', :timeout => 30
    ln = JSON.parse(ln.get)
    stats = JSON.parse(stats.get)
    timestamp = Time.now.to_i
    node = stats['nodes'].values.first
#    node['jvm']['mem']['heap_max_in_bytes'] = ln['nodes'].values.first['jvm']['mem']['heap_max_in_bytes']
    metrics = {}
    metrics['os.load_average']                  = node['os']['load_average'][0]
    metrics['os.mem.free_in_bytes']             = node['os']['mem']['free_in_bytes']
    metrics['process.mem.resident_in_bytes']    = node['process']['mem']['resident_in_bytes']
    metrics['jvm.mem.heap_used_in_bytes']       = node['jvm']['mem']['heap_used_in_bytes']
    metrics['jvm.mem.non_heap_used_in_bytes']   = node['jvm']['mem']['non_heap_used_in_bytes']
    metrics['jvm.mem.max_heap_size_in_bytes']   = node['jvm']['mem']['pools']['CMS Old Gen']['max_in_bytes'] +  node['jvm']['mem']['pools']['Code Cache']['max_in_bytes'] +  node['jvm']['mem']['pools']['Par Eden Space']['max_in_bytes'] + node['jvm']['mem']['pools']['Par Survivor Space']['max_in_bytes'] + node['jvm']['mem']['pools']['CMS Perm Gen']['max_in_bytes']
    metrics['jvm.gc.collection_time_in_millis'] = node['jvm']['gc']['collection_time_in_millis'] +  node['jvm']['mem']['pools']['CMS Old Gen']['max_in_bytes']
    metrics['jvm.threads.count']                = node['jvm']['threads']['count']
    metrics['jvm.threads.peak_count']           = node['jvm']['threads']['peak_count']
    metrics['indices.store.size_in_bytes']      = node['indices']['store']['size_in_bytes']
    metrics['indices.docs.count']               = node['indices']['docs']['count']
    metrics['transport.server_open']            = node['transport']['server_open']
    metrics['transport.rx_count']               = node['transport']['rx_count']
    metrics['transport.rx_size_in_bytes']       = node['transport']['rx_size_in_bytes']
    metrics['transport.tx_count']               = node['transport']['tx_count']
    metrics['transport.tx_size_in_bytes']       = node['transport']['tx_size_in_bytes']
    metrics['http.current_open']                = node['http']['current_open']
    metrics['http.total_opened']                = node['http']['total_opened']
    metrics['network.tcp.active_opens']         = node['network']['tcp']['active_opens']
    metrics['network.tcp.passive_opens']        = node['network']['tcp']['passive_opens']
    metrics['network.tcp.current_estab']        = node['network']['tcp']['current_estab']
    metrics['network.tcp.in_segs']              = node['network']['tcp']['in_segs']
    metrics['network.tcp.out_segs']             = node['network']['tcp']['out_segs']
    metrics['network.tcp.retrans_segs']         = node['network']['tcp']['retrans_segs']
    metrics['network.tcp.estab_resets']         = node['network']['tcp']['estab_resets']
    metrics['network.tcp.attempt_fails']        = node['network']['tcp']['attempt_fails']
    metrics['network.tcp.in_errs']              = node['network']['tcp']['in_errs']
    metrics['network.tcp.out_rsts']             = node['network']['tcp']['out_rsts']
    metrics.each do |k,v|
      output([config[:scheme], k].join("."), v, timestamp)
    end
    ok
  end

end
