#!/usr/bin/env ruby
#
# Postgres Stat Table Metrics
# ===
#
# Dependencies
# -----------
# - PSQL `track_counts` enabled
# - Ruby gem `pg`
#
#
# Copyright 2012 Kwarter, Inc <platforms@kwarter.com>
# Author Gilles Devaux <gilles.devaux@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'pg'
require 'socket'

class PostgresStatsTableMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :user,
         :description => "Postgres User",
         :short       => '-u USER',
         :long        => '--user USER'

  option :password,
         :description => "Postgres Password",
         :short       => '-p PASS',
         :long        => '--password PASS'

  option :hostname,
         :description => "Hostname to login to",
         :short       => '-h HOST',
         :long        => '--hostname HOST',
         :default     => 'localhost'

  option :port,
         :description => "Database port",
         :short       => '-P PORT',
         :long        => '--port PORT',
         :default     => 5432

  option :db,
         :description => "Database name",
         :short       => '-d DB',
         :long        => '--db DB',
         :default     => 'postgres'

  option :scope,
         :description => "Scope, see http://www.postgresql.org/docs/9.2/static/monitoring-stats.html",
         :short       => '-s SCOPE',
         :long        => '--scope SCOPE',
         :default     => 'user'

  option :scheme,
         :description => "Metric naming scheme, text to prepend to $queue_name.$metric",
         :long        => "--scheme SCHEME",
         :default     => "#{Socket.gethostname}.postgresql"

  def run
    timestamp = Time.now.to_i

    con     = PG::Connection.new(config[:hostname], config[:port], nil, nil, config[:db], config[:user], config[:password])
    request = [
        "select sum(seq_scan) as seq_scan, sum(seq_tup_read) as seq_tup_read,",
        "sum(idx_scan) as idx_scan, sum(idx_tup_fetch) as idx_tup_fetch,",
        "sum(n_tup_ins) as n_tup_ins, sum(n_tup_upd) as n_tup_upd, sum(n_tup_del) as n_tup_del,",
        "sum(n_tup_hot_upd) as n_tup_hot_upd, sum(n_live_tup) as n_live_tup, sum(n_dead_tup) as n_dead_tup",
        "from pg_stat_#{config[:scope]}_tables"
    ]
    con.exec(request.join(' ')) do |result|
      result.each do |row|
        output "#{config[:scheme]}.statstable.#{config[:db]}.seq_scan", row['seq_scan'], timestamp
        output "#{config[:scheme]}.statstable.#{config[:db]}.seq_tup_read", row['seq_tup_read'], timestamp
        output "#{config[:scheme]}.statstable.#{config[:db]}.idx_scan", row['idx_scan'], timestamp
        output "#{config[:scheme]}.statstable.#{config[:db]}.idx_tup_fetch", row['idx_tup_fetch'], timestamp
        output "#{config[:scheme]}.statstable.#{config[:db]}.n_tup_ins", row['n_tup_ins'], timestamp
        output "#{config[:scheme]}.statstable.#{config[:db]}.n_tup_upd", row['n_tup_upd'], timestamp
        output "#{config[:scheme]}.statstable.#{config[:db]}.n_tup_del", row['n_tup_del'], timestamp
        output "#{config[:scheme]}.statstable.#{config[:db]}.n_tup_hot_upd", row['n_tup_hot_upd'], timestamp
        output "#{config[:scheme]}.statstable.#{config[:db]}.n_live_tup", row['n_live_tup'], timestamp
        output "#{config[:scheme]}.statstable.#{config[:db]}.n_dead_tup", row['n_dead_tup'], timestamp
      end
    end

    ok

  end

end
