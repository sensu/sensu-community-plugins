#!/usr/bin/env ruby
#
# This plugin uses socket rather than memcached gem or ruby package.
# Copyright 2013 github.com/foomatty
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'timeout'

class MemcachedGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
         :short       => "-h HOST",
         :long        => "--host HOST",
         :description => "Memcached Host to connect to",
         :default     => 'localhost'

  option :port,
         :short       => "-p PORT",
         :long        => "--port PORT",
         :description => "Memcached Port to connect to",
         :proc        => proc { |p| p.to_i },
         :default     => 11211

  option :scheme,
         :description => "Metric naming scheme, text to prepend to metric",
         :short       => "-s SCHEME",
         :long        => "--scheme SCHEME",
         :default     => "#{::Socket.gethostname}.memcached"
  def run
    begin
      stats = {}
      metrics = {}
      Timeout.timeout(30) do
        TCPSocket.open("#{config[:host]}", "#{config[:port]}") do |socket|
          socket.print "stats\r\n"
          socket.close_write
          recv = socket.read
          recv.each_line do |line|
            if line.match('STAT')
              stats[line.split(' ')[1]] = line.split(' ')[2]
            end
          end
          metrics.update(sortMetrics(stats))
          metrics.each do |k, v|
            output "#{config[:scheme]}.#{k}", v
          end
        end
      end
      ok
    rescue Timeout::Error
     puts "timed out connecting to memcached on port #{config[:port]}"
    rescue
     puts "Can't connect to port #{config[:port]}"
     exit(1)
    end
  end

  def sortMetrics(stats)
    memcachedMetrics = {}
    memcachedMetrics['uptime'] = stats['uptime'].to_i
    memcachedMetrics['pointer_size'] = stats['pointer_size'].to_i
    memcachedMetrics['rusage_user'] = stats['rusage_user'].to_i
    memcachedMetrics['rusage_system'] = stats['rusage_system'].to_i
    memcachedMetrics['curr_connections'] = stats['curr_connections'].to_i
    memcachedMetrics['total_connections'] = stats['total_connections'].to_i
    memcachedMetrics['connection_structures'] = stats['connection_structures'].to_i
    memcachedMetrics['reserved_fds'] = stats['reserved_fds'].to_i
    memcachedMetrics['cmd_get'] = stats['cmd_get'].to_i
    memcachedMetrics['cmd_set'] = stats['cmd_set'].to_i
    memcachedMetrics['cmd_flush'] = stats['cmd_flush'].to_i
    memcachedMetrics['cmd_touch'] = stats['cmd_touch'].to_i
    memcachedMetrics['get_hits'] = stats['get_hits'].to_i
    memcachedMetrics['get_misses'] = stats['get_misses'].to_i
    memcachedMetrics['delete_misses'] = stats['delete_misses'].to_i
    memcachedMetrics['delete_hits'] = stats['delete_hits'].to_i
    memcachedMetrics['incr_misses'] = stats['incr_misses'].to_i
    memcachedMetrics['incr_hits'] = stats['incr_hits'].to_i
    memcachedMetrics['decr_misses'] = stats['decr_misses'].to_i
    memcachedMetrics['decr_hits'] = stats['decr_hits'].to_i
    memcachedMetrics['cas_misses'] = stats['cas_misses'].to_i
    memcachedMetrics['cas_hits'] = stats['cas_hits'].to_i
    memcachedMetrics['cas_badval'] = stats['cas_badval'].to_i
    memcachedMetrics['touch_hits'] = stats['touch_hits'].to_i
    memcachedMetrics['touch_misses'] = stats['touch_misses'].to_i
    memcachedMetrics['auth_cmds'] = stats['auth_cmds'].to_i
    memcachedMetrics['auth_errors'] = stats['auth_errors'].to_i
    memcachedMetrics['bytes_read'] = stats['bytes_read'].to_i
    memcachedMetrics['bytes_written'] = stats['bytes_written'].to_i
    memcachedMetrics['limit_maxbytes'] = stats['limit_maxbytes'].to_i
    memcachedMetrics['accepting_conns'] = stats['accepting_conns'].to_i
    memcachedMetrics['listen_disabled_num'] = stats['listen_disabled_num'].to_i
    memcachedMetrics['threads'] = stats['threads'].to_i
    memcachedMetrics['conn_yields'] = stats['conn_yields'].to_i
    memcachedMetrics['hash_power_level'] = stats['hash_power_level'].to_i
    memcachedMetrics['hash_bytes'] = stats['hash_bytes'].to_i
    memcachedMetrics['hash_is_expanding'] = stats['hash_is_expanding'].to_i
    memcachedMetrics['expired_unfetched'] = stats['expired_unfetched'].to_i
    memcachedMetrics['evicted_unfetched'] = stats['evicted_unfetched'].to_i
    memcachedMetrics['bytes'] = stats['bytes'].to_i
    memcachedMetrics['curr_items'] = stats['curr_items'].to_i
    memcachedMetrics['total_items'] = stats['total_items'].to_i
    memcachedMetrics['evictions'] = stats['evictions'].to_i
    memcachedMetrics['reclaimed'] = stats['reclaimed'].to_i
    memcachedMetrics
  end
end
