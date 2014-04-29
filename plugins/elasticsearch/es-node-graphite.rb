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

  option :server,
    :description => "Elasticsearch server host.",
    :short => "-h HOST",
    :long => "--host HOST",
    :default => "localhost"

  option :port,
    :description => "Elasticsearch port.",
    :short => "-p PORT",
    :long => "--port PORT",
    :default => 9200

  option :request_timeout,
    :description => "Request timeout to elasticsearch",
    :short => "-t TIMEOUT",
    :long => "--timeout TIMEOUT",
    :default => 30

  option :disable_jvm_stats,
    :description => "Return JVM statistics",
    :long => "--disable-jvm-stats",
    :boolean => true,
    :default => false

  option :disable_os_stats,
    :description => "Return OS Stats",
    :long => "--disable-os-stat",
    :boolean => true,
    :default => false

  option :disable_process_stats,
    :description => "Return process statistics",
    :long => "--disable-process-stats",
    :boolean => true,
    :default => false

  def get_es_resource(resource)
    begin
      r = RestClient::Resource.new("http://#{config[:server]}:#{config[:port]}/#{resource}?pretty", :timeout => config[:request_timeout])
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    end
  end

  def get_es_version
    info = get_es_resource('/')
    info['version']['number']
  end

  def run

    # invert various stats depending on if some flags are set
    os_stat = ( true ^ config[:disable_os_stats] )
    process_stats = ( true ^ config[:disable_process_stats] )
    jvm_stats = ( true ^ config[:disable_jvm_stats] )

    stats_query_string = [
        'clear=true',
        'indices=true',
        'fs=true',
        'http=true',
        "jvm=#{jvm_stats}",
        'network=true',
        "os=#{os_stat}",
        "process=#{process_stats}",
        'thread_pool=true',
        'transport=true',
        'thread_pool=true',
        'breaker=true'
    ].join('&')

    if Gem::Version.new(get_es_version) >= Gem::Version.new('1.0.0')
      stats = get_es_resource("_nodes/_local/stats?#{stats_query_string}")
    else
      stats = get_es_resource("_cluster/nodes/_local/stats?#{stats_query_string}")
    end

    timestamp = Time.now.to_i
    node = stats['nodes'].values.first

    metrics = {}

    if os_stat
      metrics['os.load_average']                  = node['os']['load_average'][0]
      metrics['os.mem.free_in_bytes']             = node['os']['mem']['free_in_bytes']
    end

    if process_stats
      metrics['process.mem.resident_in_bytes']    = node['process']['mem']['resident_in_bytes']
    end

    if jvm_stats
      metrics['jvm.mem.heap_used_in_bytes']       = node['jvm']['mem']['heap_used_in_bytes']
      metrics['jvm.mem.non_heap_used_in_bytes']   = node['jvm']['mem']['non_heap_used_in_bytes']
      metrics['jvm.mem.max_heap_size_in_bytes']   = 0
      node['jvm']['mem']['pools'].keys do |k|
        metrics['jvm.mem.max_heap_size_in_bytes'] += node['jvm']['mem']['pools'][k]['max_in_bytes']
      end
      # This makes absolutely no sense - not sure what it's trying to measure - @vjanelle
      # metrics['jvm.gc.collection_time_in_millis'] = node['jvm']['gc']['collection_time_in_millis'] +  node['jvm']['mem']['pools']['CMS Old Gen']['max_in_bytes']
      node['jvm']['gc']['collectors'].each do |gc,gc_value|
        gc_value.each do |k,v|
          # this contains stupid things like '28ms' and '2s', and there's already
          # something that counts in millis, which makes more sense
          if !k.end_with? "collection_time"
            metrics["jvm.gc.collectors.#{gc}.#{k}"] = v
          end
        end
      end
      metrics['jvm.threads.count']                = node['jvm']['threads']['count']
      metrics['jvm.threads.peak_count']           = node['jvm']['threads']['peak_count']
    end

    node['indices'].each do |type, index|
      index.each do |k,v|
        if !k.end_with? "_time"
          metrics["indicies.#{type}.#{k}"] = v
        end
      end
    end

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
    metrics.each do |k, v|
      output([config[:scheme], k].join("."), v.to_s, timestamp)
    end
    ok
  end

end
