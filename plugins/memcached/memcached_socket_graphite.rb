#! /usr/bin/env ruby
#
#   memcached-socket-graphite
#
# DESCRIPTION:
#   This plugin uses socket rather than memcached gem or ruby package.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: socket
#
# USAGE:
#  #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2013 github.com/foomatty
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'timeout'

class MemcachedGraphite < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Memcached Host to connect to',
         default: 'localhost'

  option :port,
         short: '-p PORT',
         long: '--port PORT',
         description: 'Memcached Port to connect to',
         proc: proc(&:to_i),
         default: 11_211

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{::Socket.gethostname}.memcached"
  def run
    stats = {}
    metrics = {}
    Timeout.timeout(30) do
      TCPSocket.open("#{config[:host]}", "#{config[:port]}") do |socket|
        socket.print "stats\r\n"
        socket.close_write
        recv = socket.read
        recv.each_line do |line|
          stats[line.split(' ')[1]] = line.split(' ')[2] if line.match('STAT')
        end
        metrics.update(sort_metrics(stats))
        metrics.each do |k, v|
          output "#{config[:scheme]}.#{k}", v
        end
      end
    end
  rescue Timeout::Error
    warning "timed out connecting to memcached on port #{config[:port]}"
  rescue
    critical "Can't connect to port #{config[:port]}"
  else
    ok
  end

  def sort_metrics(stats)
    memcached_metrics = {}
    memcached_metrics['uptime'] = stats['uptime'].to_i
    memcached_metrics['pointer_size'] = stats['pointer_size'].to_i
    memcached_metrics['rusage_user'] = stats['rusage_user'].to_i
    memcached_metrics['rusage_system'] = stats['rusage_system'].to_i
    memcached_metrics['curr_connections'] = stats['curr_connections'].to_i
    memcached_metrics['total_connections'] = stats['total_connections'].to_i
    memcached_metrics['connection_structures'] = stats['connection_structures'].to_i
    memcached_metrics['reserved_fds'] = stats['reserved_fds'].to_i
    memcached_metrics['cmd_get'] = stats['cmd_get'].to_i
    memcached_metrics['cmd_set'] = stats['cmd_set'].to_i
    memcached_metrics['cmd_flush'] = stats['cmd_flush'].to_i
    memcached_metrics['cmd_touch'] = stats['cmd_touch'].to_i
    memcached_metrics['get_hits'] = stats['get_hits'].to_i
    memcached_metrics['get_misses'] = stats['get_misses'].to_i
    memcached_metrics['delete_misses'] = stats['delete_misses'].to_i
    memcached_metrics['delete_hits'] = stats['delete_hits'].to_i
    memcached_metrics['incr_misses'] = stats['incr_misses'].to_i
    memcached_metrics['incr_hits'] = stats['incr_hits'].to_i
    memcached_metrics['decr_misses'] = stats['decr_misses'].to_i
    memcached_metrics['decr_hits'] = stats['decr_hits'].to_i
    memcached_metrics['cas_misses'] = stats['cas_misses'].to_i
    memcached_metrics['cas_hits'] = stats['cas_hits'].to_i
    memcached_metrics['cas_badval'] = stats['cas_badval'].to_i
    memcached_metrics['touch_hits'] = stats['touch_hits'].to_i
    memcached_metrics['touch_misses'] = stats['touch_misses'].to_i
    memcached_metrics['auth_cmds'] = stats['auth_cmds'].to_i
    memcached_metrics['auth_errors'] = stats['auth_errors'].to_i
    memcached_metrics['bytes_read'] = stats['bytes_read'].to_i
    memcached_metrics['bytes_written'] = stats['bytes_written'].to_i
    memcached_metrics['limit_maxbytes'] = stats['limit_maxbytes'].to_i
    memcached_metrics['accepting_conns'] = stats['accepting_conns'].to_i
    memcached_metrics['listen_disabled_num'] = stats['listen_disabled_num'].to_i
    memcached_metrics['threads'] = stats['threads'].to_i
    memcached_metrics['conn_yields'] = stats['conn_yields'].to_i
    memcached_metrics['hash_power_level'] = stats['hash_power_level'].to_i
    memcached_metrics['hash_bytes'] = stats['hash_bytes'].to_i
    memcached_metrics['hash_is_expanding'] = stats['hash_is_expanding'].to_i
    memcached_metrics['expired_unfetched'] = stats['expired_unfetched'].to_i
    memcached_metrics['evicted_unfetched'] = stats['evicted_unfetched'].to_i
    memcached_metrics['bytes'] = stats['bytes'].to_i
    memcached_metrics['curr_items'] = stats['curr_items'].to_i
    memcached_metrics['total_items'] = stats['total_items'].to_i
    memcached_metrics['evictions'] = stats['evictions'].to_i
    memcached_metrics['reclaimed'] = stats['reclaimed'].to_i
    memcached_metrics
  end
end
