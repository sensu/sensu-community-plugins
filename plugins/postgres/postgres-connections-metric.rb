#!/usr/bin/env ruby
#
# Postgres Connection Metrics
# ===
#
# Dependencies
# -----------
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

class PostgresStatsDBMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :user,
         description: 'Postgres User',
         short: '-u USER',
         long: '--user USER'

  option :password,
         description: 'Postgres Password',
         short: '-p PASS',
         long: '--password PASS'

  option :hostname,
         description: 'Hostname to login to',
         short: '-h HOST',
         long: '--hostname HOST',
         default: 'localhost'

  option :port,
         description: 'Database port',
         short: '-P PORT',
         long: '--port PORT',
         default: 5432

  option :db,
         description: 'Database name',
         short: '-d DB',
         long: '--db DB',
         default: 'postgres'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to $queue_name.$metric',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.postgresql"

  def run
    timestamp = Time.now.to_i

    con     = PG::Connection.new(config[:hostname], config[:port], nil, nil, 'postgres', config[:user], config[:password])
    request = [
      'select count(*), waiting from pg_stat_activity',
      "where datname = '#{config[:db]}' group by waiting"
    ]

    metrics = {
      active: 0,
      waiting: 0
    }
    con.exec(request.join(' ')) do |result|
      result.each do |row|
        if row['waiting']
          metrics[:waiting] = row['count']
        else
          metrics[:active] = row['count']
        end
      end
    end

    metrics.each do |metric, value|
      output "#{config[:scheme]}.connections.#{config[:db]}.#{metric}", value, timestamp
    end

    ok
  end
end
