#!/usr/bin/env ruby
#
# Percona cluster stats into graphite
# ===
#
# Copyright 2012 Pete Shima <me@peteshima.com>, Chris Alexander <chris.alexander@import.io>
# Additional hacks by Joe Miller - https://github.com/joemiller
# Modified for Percona cluster statistics by Chris Alexander, import.io - https://github.com/chrisalexander - https://github.com/import-io
#
# Depends on mysql2:
# gem install mysql2
#
# This will not return anything on MySQL servers, or on Percona servers that do not have clustering running
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'mysql2'
require 'socket'

class PerconaCluster2Graphite < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Mysql Host to connect to',
         required: true

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'Mysql Port to connect to',
         proc: proc(&:to_i),
         default: 3306

  option :username,
         short: '-u USERNAME',
         long: '--user USERNAME',
         description: 'Mysql Username',
         required: true

  option :password,
         short: '-p PASSWORD',
         long: '--pass PASSWORD',
         description: 'Mysql password',
         default: ''

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.percona"

  def fix_and_output_evs_repl_latency_data(row)
    # see https://github.com/codership/galera/issues/67 for documentation on field mappings
    data = row['Value'].split('/')
    output "#{config[:scheme]}.mysql.wsrep_evs_repl_latency_min", data[0]
    output "#{config[:scheme]}.mysql.wsrep_evs_repl_latency_avg", data[1]
    output "#{config[:scheme]}.mysql.wsrep_evs_repl_latency_max", data[2]
    output "#{config[:scheme]}.mysql.wsrep_evs_repl_latency_stddev", data[3]
    output "#{config[:scheme]}.mysql.wsrep_evs_repl_latency_samplesize", data[4]
  end

  def run
    metrics = {
      'cluster' => {
        'wsrep_last_committed' => 'last_committed',
        'wsrep_replicated' => 'replicated',
        'wsrep_replicated_bytes' => 'replicated_bytes',
        'wsrep_received' => 'received',
        'wsrep_received_bytes' => 'received_bytes',
        'wsrep_local_commits' => 'local_commits',
        'wsrep_local_cert_failures' => 'local_cert_failures',
        'wsrep_local_bf_aborts' => 'local_bf_aborts',
        'wsrep_local_replays' => 'local_replays',
        'wsrep_local_send_queue' => 'local_send_queue',
        'wsrep_local_send_queue_avg' => 'local_send_queue_avg',
        'wsrep_local_recv_queue' => 'local_recv_queue',
        'wsrep_local_recv_queue_avg' => 'local_recv_queue_avg',
        'wsrep_flow_control_paused' => 'flow_control_paused',
        'wsrep_flow_control_sent' => 'flow_control_sent',
        'wsrep_flow_control_recv' => 'flow_control_recv',
        'wsrep_cert_deps_distance' => 'cert_deps_distance',
        'wsrep_apply_oooe' => 'apply_oooe',
        'wsrep_apply_oool' => 'apply_oool',
        'wsrep_apply_window' => 'apply_window',
        'wsrep_commit_oooe' => 'commit_oooe',
        'wsrep_commit_oool' => 'commit_oool',
        'wsrep_commit_window' => 'commit_window',
        'wsrep_local_state' => 'local_state',
        'wsrep_cert_index_size' => 'cert_index_size',
        'wsrep_causal_reads' => 'causal_reads',
        'wsrep_cluster_conf_id' => 'cluster_conf_id',
        'wsrep_cluster_size' => 'cluster_size',
        'wsrep_local_index' => 'local_index',
        'wsrep_evs_repl_latency' => 'evs_repl_latency'
      }
    }

    begin
      mysql = Mysql2::Client.new(
        host: config[:host],
        port: config[:port],
        username: config[:username],
        password: config[:password]
        )

      results = mysql.query("SHOW GLOBAL STATUS LIKE 'wsrep_%'")
    rescue => e
      puts e.message
    end

    results.each do |row|
      # special handling for wsrep_evs_repl_latency as this contains forward slash delimited data
      fix_and_output_evs_repl_latency_data(row) if row['Variable_name'] == 'wsrep_evs_repl_latency'
      metrics.each do |category, var_mapping|
        if var_mapping.key?(row['Variable_name'])
          output "#{config[:scheme]}.mysql.#{category}.#{var_mapping[row['Variable_name']]}", row['Value']
        end
      end
    end

    ok
  end
end
