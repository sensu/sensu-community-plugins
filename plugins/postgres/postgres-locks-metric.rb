#!/usr/bin/env ruby
#
# Postgres Locks Metrics
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

  option :scheme,
         :description => "Metric naming scheme, text to prepend to $queue_name.$metric",
         :long        => "--scheme SCHEME",
         :default     => "#{Socket.gethostname}.postgresql"

  def run
    timestamp = Time.now.to_i

    metrics = {
        :accessshare          => 0,
        :rowshare             => 0,
        :rowexclusive         => 0,
        :shareupdateexclusive => 0,
        :share                => 0,
        :sharerowexclusive    => 0,
        :exclusive            => 0,
        :accessexclusive      => 0
    }

    con     = PG::Connection.new(config[:hostname], config[:port], nil, nil, 'postgres', config[:user], config[:password])
    request = [
        "SELECT mode, count(mode) FROM pg_locks",
        "where database = (select oid from pg_database where datname = '#{config[:db]}')",
        "group by mode"
    ]

    con.exec(request.join(' ')) do |result|
      result.each do |row|
        metrics[row['mode'].downcase.to_sym] += 1
      end
    end

    metrics.each do |metric, value|
      output "#{config[:scheme]}.locks.#{config[:db]}.#{metric}", value, timestamp
    end

    ok

  end

end
