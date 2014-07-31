#!/usr/bin/env ruby
#
# Cassandra metrics using nodetool
# ===
#
# DESCRIPTION:
#   This plugin uses Apache Cassandra's `nodetool` to collect metrics
#   from an instance of Cassandra. Default is localhost and port 7199.
#   Use 8080 for Cassandra < 0.8.
#
#   By default, only 'info' and 'tpstats' metrics will be output, but
#   can be disabled with `--no-info` or `--no-tpstats`.
#
#   Use `--cfstats` to get detailed metrics on keyspaces and column
#   families.
#
#   Only column-families matching a regex will be output if the
#   `--filter REGEX` flag is used.
#
# OUTPUT:
#   Graphite plain-text format (name value timestamp\n)
#
# PLATFORMS:
#   linux
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   Cassandra's nodetool
#
# USAGE:
#
#   info and tpstats
#   ----------------
#
#     $ ./cassandra-metrics.rb
#
#      host.cassandra.load  75696701.44 1344547246
#      host.cassandra.uptime  580640  1344547246
#      host.cassandra.heap.used 88332042.24 1344547246
#      host.cassandra.heap.total  408944640.0 1344547246
#      host.cassandra.exceptions  0 1344547246
#      host.cassandra.threadpool.ReadStage.active 0 1344547246
#      host.cassandra.threadpool.ReadStage.pending  0 1344547246
#      ...
#
#   All metrics, including keyspaces and column families
#   ----------------------------------------------------
#
#     $ ./cassandra-metrics.rb --cfstats
#
#   Show metrics for column-families matching '.*user.*' regex
#   ----------------------------------------------------------
#
#     $ ./cassandra-metrics.rb  --cfstats --filter .*user.*
#
#   Show keyspace metrics, but not column family metrics
#   ----------------------------------------------------
#
#     $ ./cassandra-metrics.rb --cfstats NOTHING_SHOULD_MATCH_THIS_REGEX
#
# Copyright 2012 Joe Miller https://github.com/joemiller
#
# Heavily inspired by Datadog's python plugin:
# https://github.com/miketheman/dd-agent/blob/master/checks/cassandra.py
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# rubocop:disable AssignmentInCondition

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

UNITS_FACTOR = {
  'bytes' => 1,
  'KB' => 1024,
  'MB' => 1024**2,
  'GB' => 1024**3,
  'TB' => 1024**4
}

class CassandraMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :hostname,
    :short => "-h HOSTNAME",
    :long => "--host HOSTNAME",
    :description => "cassandra hostname",
    :default => "localhost"

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "cassandra JMX port",
    :default => "7199"

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.cassandra"

  option :filter_regex,
    :description => "regular expression for filtering column families (use with --cfstats)",
    :on => :tail,
    :short => "-f REGEX",
    :long => "--filter REGEX"

  option :info,
    :description => 'output high-level Cassandra "info" metrics (default: yes)',
    :on => :tail,
    :short => '-i',
    :long => '--[no-]info',
    :boolean => true,
    :default => true

  option :compactionstats,
    :description => 'output Cassandra "compactionstats" metrics (default: yes)',
    :on => :tail,
    :short => '-o',
    :long => '--[no-]compactionstats',
    :boolean => true,
    :default => true

  option :tpstats,
    :description => 'output Cassandra threadPool metrics (default: yes)',
    :on => :tail,
    :short => '-t',
    :long => '--[no-]tpstats',
    :boolean => true,
    :default => true

  option :cfstats,
    :description => 'output metrics on keyspaces and column families (default: no)',
    :on => :tail,
    :short => '-c',
    :long => '--[no-]cfstats',
    :boolean => true,
    :default => false

  # convert_to_bytes(512, 'KB') => 524288
  # convert_to_bytes(1, 'MB') => 1048576
  def convert_to_bytes(size, unit)
    size.to_f * UNITS_FACTOR[unit]
  end

  # execute cassandra's nodetool and return output as string
  def nodetool_cmd(cmd)
    `nodetool -h #{config[:hostname]} -p #{config[:port]} #{cmd}`
  end

  # nodetool -h localhost info:
  # v 0.7
  #
  # 36299342986353445520010708318471778930
  # Load             : 457.02 KB
  # Generation No    : 1295816448
  # Uptime (seconds) : 95
  # Heap Memory (MB) : 521.86 / 1019.88
  #
  # v 0.8
  # Token            : 51022655878160265769426795515063697984
  # Gossip active    : True
  # Load             : 283.87 GB
  # Generation No    : 1331653944
  # Uptime (seconds) : 188319
  # Heap Memory (MB) : 2527.04 / 3830.00
  # Data Center      : 283
  # Rack             : 76
  # Exceptions       : 0
  #
  # v 1.1
  # Token            : 141784319550391026443072753096570088106
  # Gossip active    : true
  # Thrift active    : true
  # Load             : 821.59 GB
  # Generation No    : 1345535280
  # Uptime (seconds) : 34269
  # Heap Memory (MB) : 2382.02 / 3032.00
  # Data Center      : datacenter1
  # Rack             : rack1
  # Exceptions       : 0
  # Key Cache        : size 28141776 (bytes), capacity 104857584 (bytes), 9489268 hits, 9676043 requests, 0.987 recent hit rate, 14400 save period in seconds
  # Row Cache        : size 7947581 (bytes), capacity 1048576000 (bytes), 84005 hits, 104727 requests, 0.701 recent hit rate, 0 save period in seconds
  #
  # According to io/util/FileUtils.java units for load are:
  # TB/GB/MB/KB/bytes
  #
  def parse_info
    info = nodetool_cmd('info')
    info.each_line do |line|
      if m = line.match(/^Exceptions\s*:\s+([0-9]+)$/)
        output "#{config[:scheme]}.exceptions", m[1], @timestamp
      end

      if m = line.match(/^Load\s*:\s+([0-9.]+)\s+([KMGT]B|bytes)$/)
        output "#{config[:scheme]}.load", convert_to_bytes(m[1], m[2]), @timestamp
      end

      if m = line.match(/^Uptime[^:]+:\s+(\d+)$/)
        output "#{config[:scheme]}.uptime", m[1], @timestamp
      end

      if m = line.match(/^Heap Memory[^:]+:\s+([0-9.]+)\s+\/\s+([0-9.]+)$/)
        output "#{config[:scheme]}.heap.used", convert_to_bytes(m[1], 'MB'), @timestamp
        output "#{config[:scheme]}.heap.total", convert_to_bytes(m[2], 'MB'), @timestamp
      end

      # v1.1+
      if m = line.match(/^Key Cache[^:]+: size ([0-9]+) \(bytes\), capacity ([0-9]+) \(bytes\), ([0-9]+) hits, ([0-9]+) requests/)
        output "#{config[:scheme]}.key_cache.size", m[1], @timestamp
        output "#{config[:scheme]}.key_cache.capacity", m[2], @timestamp
        output "#{config[:scheme]}.key_cache.hits", m[3], @timestamp
        output "#{config[:scheme]}.key_cache.requests", m[4], @timestamp
      end

      if m = line.match(/^Row Cache[^:]+: size ([0-9]+) \(bytes\), capacity ([0-9]+) \(bytes\), ([0-9]+) hits, ([0-9]+) requests/)
        output "#{config[:scheme]}.row_cache.size", m[1], @timestamp
        output "#{config[:scheme]}.row_cache.capacity", m[2], @timestamp
        output "#{config[:scheme]}.row_cache.hits", m[3], @timestamp
        output "#{config[:scheme]}.row_cache.requests", m[4], @timestamp
      end
    end
  end

  # nodetool -h localhost tpstats:
  # Pool Name                    Active   Pending      Completed   Blocked  All time blocked
  # ReadStage                         0         0         282971         0                 0
  # RequestResponseStage              0         0          32926         0                 0
  # MutationStage                     0         0        3216105         0                 0
  # ReadRepairStage                   0         0              0         0                 0
  # ReplicateOnWriteStage             0         0              0         0                 0
  # GossipStage                       0         0              0         0                 0
  # AntiEntropyStage                  0         0              0         0                 0
  # MigrationStage                    0         0            188         0                 0
  # MemtablePostFlusher               0         0            110         0                 0
  # StreamStage                       0         0              0         0                 0
  # FlushWriter                       0         0            110         0                 0
  # MiscStage                         0         0              0         0                 0
  # InternalResponseStage             0         0            179         0                 0
  # HintedHandoff                     0         0              0         0                 0
  #
  # Message type           Dropped
  # RANGE_SLICE                  0
  # READ_REPAIR                  0
  # BINARY                       0
  # READ                         0
  # MUTATION                     0
  # REQUEST_RESPONSE             0
  def parse_tpstats
    tpstats = nodetool_cmd('tpstats')
    tpstats.each_line do |line|
      next if line.match(/^Pool Name/)
      next if line.match(/^Message type/)

      if m = line.match(/^(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/)
        (thread, active, pending, completed, blocked, _) = m.captures

        output "#{config[:scheme]}.threadpool.#{thread}.active", active, @timestamp
        output "#{config[:scheme]}.threadpool.#{thread}.pending", pending, @timestamp
        output "#{config[:scheme]}.threadpool.#{thread}.completed", completed, @timestamp
        output "#{config[:scheme]}.threadpool.#{thread}.blocked", blocked, @timestamp
      end

      if m = line.match(/^(\w+)\s+(\d+)$/)
        (message_type, dropped) = m.captures
        output "#{config[:scheme]}.message_type.#{message_type}.dropped", dropped, @timestamp
      end
    end
  end

  # nodetool -h localhost compactionstats
  # pending tasks: 1
  #    compaction type        keyspace   column family bytes compacted     bytes total  progress
  #     ....
  #
  # note: we are only capturing the 'pending tasks' stats
  def parse_compactionstats
    cstats = nodetool_cmd('compactionstats')
    cstats.each_line do |line|
      if m = line.match(/^pending tasks:\s+([0-9]+)/)
        output "#{config[:scheme]}.compactionstats.pending_tasks", m[1], @timestamp
      end
    end
  end

  # nodetool -h localhost cfstats
  # Keyspace: system
  #   Read Count: 216
  #   Read Latency: 1.4066805555555557 ms.
  #   Write Count: 36
  #   Write Latency: 0.32755555555555554 ms.
  #   Pending Tasks: 0
  #     Column Family: NodeIdInfo
  #     SSTable count: 0
  #     Space used (live): 0
  #     Space used (total): 0
  #     Number of Keys (estimate): 0
  #     Memtable Columns Count: 0
  #     Memtable Data Size: 0
  #     Memtable Switch Count: 0
  #     Read Count: 0
  #     Read Latency: NaN ms.
  #     Write Count: 0
  #     Write Latency: NaN ms.
  #     Pending Tasks: 0
  #     Bloom Filter False Postives: 0
  #     Bloom Filter False Ratio: 0.00000
  #     Bloom Filter Space Used: 0
  #     Key cache capacity: 1
  #     Key cache size: 0
  #     Key cache hit rate: NaN
  #     Row cache: disabled
  #     Compacted row minimum size: 0
  #     Compacted row maximum size: 0
  #     Compacted row mean size: 0
  #
  # some notes on parsing cfstats output:
  # - a line preceeded by 1 tab contains keyspace metrics
  # - a line preceeded by 2 tabs contains column family metrics
  def parse_cfstats

    def get_metric(string)
      string.strip!
      (metric, value) = string.split(': ')
      if metric.nil? || value.nil?
        return [nil, nil]
      else
        # sanitize metric names for graphite
        metric.gsub!(/[^a-zA-Z0-9]/, '_')  # convert all other chars to _
        metric.gsub!(/[_]*$/, '')          # remove any _'s at end of the string
        metric.gsub!(/[_]{2,}/, '_')       # convert sequence of multiple _'s to single _
        metric.downcase!
        # sanitize metric values for graphite. Numbers only, please.
        value = value.chomp(' ms.').gsub(/([0-9.]+)$/, '\1')
      end
      [metric, value]
    end

    cfstats = nodetool_cmd('cfstats')

    keyspace = nil
    cf = nil

    cfstats.each_line do |line|
      num_indents = line.count("\t")
      if m = line.match(/^Keyspace:\s+(\w+)$/)
        keyspace = m[1]
      elsif m = line.match(/\t\tColumn Family[^:]*:\s+(\w+)$/)
        cf = m[1]
      elsif num_indents == 0
        # keyspace = nil
        cf = nil
      elsif num_indents == 2 && !cf.nil?
        # a column family metric
        if config[:filter_regex]
          unless cf.match(config[:filter_regex])
            next
          end
        end
        (metric, value) = get_metric(line)
        output "#{config[:scheme]}.#{keyspace}.#{cf}.#{metric}", value, @timestamp unless value == "disabled"
      elsif num_indents == 1 && !keyspace.nil?
        # a keyspace metric
        (metric, value) = get_metric(line)
        output "#{config[:scheme]}.#{keyspace}.#{metric}", value, @timestamp
      end
    end
  end

  def run
    @timestamp = Time.now.to_i

    parse_info    if config[:info]
    parse_compactionstats if config[:compactionstats]
    parse_tpstats if config[:tpstats]
    parse_cfstats if config[:cfstats]

    ok
  end

end
