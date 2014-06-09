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
# 2014/04
# Modifid by Vincent Janelle @randomfrequency http://github.com/vjanelle
# Add more metrics, fix es 1.x URLs, translate graphite stats from
# names directly
#
# 2012/12 - Modified by Zach Dunn @SillySophist http://github.com/zadunn
# To add more metrics, and correct for new versins of ES. Tested on
# ES Version 0.19.8
#
# Copyright 2013 Vincent Janelle <randomfrequency@gmail.com>
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
    :proc => proc {|a| a.to_i },
    :default => 9200

  option :request_timeout,
    :description => "Request timeout to elasticsearch",
    :short => "-t TIMEOUT",
    :long => "--timeout TIMEOUT",
    :default => 30

  option :disable_jvm_stats,
    :description => "Disable JVM statistics",
    :long => "--disable-jvm-stats",
    :boolean => true,
    :default => false

  option :disable_os_stats,
    :description => "Disable OS Stats",
    :long => "--disable-os-stat",
    :boolean => true,
    :default => false

  option :disable_process_stats,
    :description => "Disable process statistics",
    :long => "--disable-process-stats",
    :boolean => true,
    :default => false

  option :disable_thread_pool_stats,
    :description => "Disable thread-pool statistics",
    :long => "--disable-thread-pool-stats",
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
    os_stat = !config[:disable_os_stats]
    process_stats = !config[:disable_process_stats]
    jvm_stats = !config[:disable_jvm_stats]
    tp_stats = !config[:disable_thread_pool_stats]

    stats_query_string = [
        "clear=true",
        "indices=true",
        "http=true",
        "jvm=#{jvm_stats}",
        "network=true",
        "os=#{os_stat}",
        "process=#{process_stats}",
        "thread_pool=#{tp_stats}",
        "transport=true",
        "thread_pool=true"
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
      metrics['os.load_average.1']                = node['os']['load_average'][0]
      metrics['os.load_average.5']                = node['os']['load_average'][1]
      metrics['os.load_average.15']               = node['os']['load_average'][2]
      metrics['os.mem.free_in_bytes']             = node['os']['mem']['free_in_bytes']
    end

    # ... Process uptime in millis?
    metrics['os.uptime'] = node['os']['uptime_in_millis']

    if process_stats
      metrics['process.mem.resident_in_bytes']    = node['process']['mem']['resident_in_bytes']
    end

    if jvm_stats
      metrics['jvm.mem.heap_used_in_bytes']       = node['jvm']['mem']['heap_used_in_bytes']
      metrics['jvm.mem.non_heap_used_in_bytes']   = node['jvm']['mem']['non_heap_used_in_bytes']
      metrics['jvm.mem.max_heap_size_in_bytes']   = 0

      node['jvm']['mem']['pools'].each do |k, v|
        metrics["jvm.mem.#{k.gsub(' ', '_')}.max_in_bytes"] = v['max_in_bytes']
        metrics['jvm.mem.max_heap_size_in_bytes'] += v['max_in_bytes']
      end

      # This makes absolutely no sense - not sure what it's trying to measure - @vjanelle
      # metrics['jvm.gc.collection_time_in_millis'] = node['jvm']['gc']['collection_time_in_millis'] + \
      # node['jvm']['mem']['pools']['CMS Old Gen']['max_in_bytes']

      node['jvm']['gc']['collectors'].each do |gc, gc_value|
        gc_value.each do |k, v|
          # this contains stupid things like '28ms' and '2s', and there's already
          # something that counts in millis, which makes more sense
          unless k.end_with? "collection_time"
            metrics["jvm.gc.collectors.#{gc}.#{k}"] = v
          end
        end
      end

      metrics['jvm.threads.count']                = node['jvm']['threads']['count']
      metrics['jvm.threads.peak_count']           = node['jvm']['threads']['peak_count']
    end

    node['indices'].each do |type,  index|
      index.each do |k, v|
        unless (k =~ /(_time|memory|size$)/)
          metrics["indicies.#{type}.#{k}"] = v
        end
      end
    end

    node['transport'].each do |k, v|
      unless (k =~ /(_size$)/)
        metrics["transport.#{k}"] = v
      end
    end

    metrics['http.current_open']                = node['http']['current_open']
    metrics['http.total_opened']                = node['http']['total_opened']

    metrics['network.tcp.active_opens']         = node['network']['tcp']['active_opens']
    metrics['network.tcp.passive_opens']        = node['network']['tcp']['passive_opens']

    metrics['network.tcp.in_segs']              = node['network']['tcp']['in_segs']
    metrics['network.tcp.out_segs']             = node['network']['tcp']['out_segs']
    metrics['network.tcp.retrans_segs']         = node['network']['tcp']['retrans_segs']
    metrics['network.tcp.attempt_fails']        = node['network']['tcp']['attempt_fails']
    metrics['network.tcp.in_errs']              = node['network']['tcp']['in_errs']
    metrics['network.tcp.out_rsts']             = node['network']['tcp']['out_rsts']

    metrics['network.tcp.curr_estab']           = node['network']['tcp']['curr_estab']
    metrics['network.tcp.estab_resets']         = node['network']['tcp']['estab_resets']

    node['thread_pool'].each do |pool, stat|
      stat.each do |k, v|
        metrics["tread_pool.#{pool}.#{k}"] = v
      end
    end

    metrics.each do |k, v|
      output([config[:scheme], k].join("."), v, timestamp)
    end
    ok
  end

end
