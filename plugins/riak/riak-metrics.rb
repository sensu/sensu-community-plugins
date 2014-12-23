#!/usr/bin/env ruby
#
# Pull riak metrics through /stats
# ===
#
# Copyright 2012 Pete Shima <me@peteshima.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'socket'
require 'json'

class RiakMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :hostname,
         short: '-h HOSTNAME',
         long: '--host HOSTNAME',
         description: 'Riak hostname',
         default: 'localhost'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'Riak port',
         default: '8098'

  option :path,
         short: '-q STATUSPATH',
         long: '--statspath STATUSPATH',
         description: 'Path to stats url',
         default: 'stats'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.riak"

  def run
    res = Net::HTTP.start(config[:hostname], config[:port]) do |http|
      req = Net::HTTP::Get.new("/#{config[:path]}")
      http.request(req)
    end

    stats = JSON.parse(res.body)

    exclude = %w(vnode_index_reads
                 vnode_index_writes
                 vnode_index_writes_postings
                 vnode_index_deletes
                 vnode_index_deletes_postings
                 read_repairs
                 vnode_gets_total
                 vnode_puts_total
                 vnode_index_reads_total
                 vnode_index_writes_total
                 vnode_index_writes_postings_total
                 vnode_index_deletes_total
                 vnode_index_deletes_postings_total
                 node_gets
                 node_gets_total
                 node_get_fsm_time_mean
                 node_get_fsm_time_median
                 node_get_fsm_time_95
                 node_get_fsm_time_99
                 node_get_fsm_time_100
                 node_puts
                 node_puts_total
                 node_put_fsm_time_mean
                 node_put_fsm_time_median
                 node_put_fsm_time_95
                 node_put_fsm_time_99
                 node_put_fsm_time_100
                 node_get_fsm_siblings_mean
                 node_get_fsm_siblings_median
                 node_get_fsm_siblings_95
                 node_get_fsm_siblings_99
                 node_get_fsm_siblings_100
                 node_get_fsm_objsize_mean
                 node_get_fsm_objsize_median
                 node_get_fsm_objsize_95
                 node_get_fsm_objsize_99
                 node_get_fsm_objsize_100
                 read_repairs_total
                 coord_redirs_total
                 precommit_fail
                 postcommit_fail
                 cpu_nprocs
                 cpu_avg1
                 cpu_avg5
                 cpu_avg15
                 mem_total
                 mem_allocated
                 sys_global_heaps_size
                 sys_logical_processors
                 sys_process_count
                 sys_thread_pool_size
                 sys_wordsize
                 ring_num_partitions
                 ring_creation_size pbc_connects_total
                 pbc_connects
                 pbc_active
                 executing_mappers
                 memory_total
                 memory_processes
                 memory_processes_used
                 memory_system
                 memory_atom
                 memory_atom_used
                 memory_binary
                 memory_code
                 memory_ets
                 ignored_gossip_total
                 rings_reconciled_total
                 rings_reconciled
                 gossip_received
                 converge_delay_max
                 converge_delay_mean
                 rebalance_delay_max
                 rebalance_delay_mean
                 riak_kv_vnodes_running
                 riak_kv_vnodeq_min
                 riak_kv_vnodeq_median
                 riak_kv_vnodeq_mean
                 riak_kv_vnodeq_max
                 riak_kv_vnodeq_total
                 riak_pipe_vnodes_running
                 riak_pipe_vnodeq_min
                 riak_pipe_vnodeq_median
                 riak_pipe_vnodeq_mean
                 riak_pipe_vnodeq_max
                 riak_pipe_vnodeq_total)

    stats.reject { |k, _v| exclude.include?(k) }.select { |k, _v| stats[k].is_a? Integer }.each do |k, v|
      output "#{config[:scheme]}.#{k}", v
    end

    ok
  end
end
