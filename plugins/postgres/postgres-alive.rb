#!/usr/bin/env ruby
#
# Postgres Alive Plugin
#
# This plugin attempts to login to postgres with provided credentials.
#
# Copyright 2012 Lewis Preson & Tom Bassindale
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'pg'

class CheckPostgres < Sensu::Plugin::Check::CLI
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
         long: '--hostname HOST'

  option :database,
         description: 'Database schema to connect to',
         short: '-d DATABASE',
         long: '--database DATABASE',
         default: 'test'

  option :port,
         description: 'Database port',
         short: '-P PORT',
         long: '--port PORT',
         default: 5432

  def run
    con = PG::Connection.new(config[:hostname], config[:port], nil, nil, config[:database], config[:user], config[:password])
    res = con.exec('select version();')
    info = res.first

    ok "Server version: #{info}"
  rescue PG::Error => e
    critical "Error message: #{e.error.split("\n").first}"
  ensure
    con.close if con
  end
end
