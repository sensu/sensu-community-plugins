#! /usr/bin/env ruby
#
#   <script name>
#
# DESCRIPTION:
#   what is this thing supposed to do, monitor?  How do alerts or
#   alarms work?
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   <your name>  <your email>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

# !/usr/bin/env ruby
#
# MySQL Health Plugin
# ===
#
# This plugin counts the maximum connections your MySQL has reached and warns you according to specified limits
#
# Copyright 2012 Panagiotis Papadomitsos <pj@ezgr.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'mysql'

class CheckMySQLHealth < Sensu::Plugin::Check::CLI
  option :user,
         description: 'MySQL User',
         short: '-u USER',
         long: '--user USER',
         default: 'root'

  option :password,
         description: 'MySQL Password',
         short: '-p PASS',
         long: '--password PASS',
         required: true

  option :hostname,
         description: 'Hostname to login to',
         short: '-h HOST',
         long: '--hostname HOST',
         default: 'localhost'

  option :port,
         description: 'Port to connect to',
         short: '-P PORT',
         long: '--port PORT',
         default: '3306'

  option :socket,
         description: 'Socket to use',
         short: '-s SOCKET',
         long: '--socket SOCKET'

  option :maxwarn,
         description: "Number of connections upon which we'll issue a warning",
         short: '-w NUMBER',
         long: '--warnnum NUMBER',
         default: 100

  option :maxcrit,
         description: "Number of connections upon which we'll issue an alert",
         short: '-c NUMBER',
         long: '--critnum NUMBER',
         default: 128

  option :usepc,
         description: 'Use percentage of defined max connections instead of absolute number',
         short: '-a',
         long: '--percentage',
         default: false

  def run
    db = Mysql.real_connect(config[:hostname], config[:user], config[:password], config[:database], config[:port].to_i, config[:socket])
    max_con = db
        .query("SHOW VARIABLES LIKE 'max_connections'")
        .fetch_hash
        .fetch('Value')
        .to_i
    used_con = db
        .query("SHOW GLOBAL STATUS LIKE 'Threads_connected'")
        .fetch_hash
        .fetch('Value')
        .to_i
    if config[:usepc]
      pc = used_con.fdiv(max_con) * 100
      critical "Max connections reached in MySQL: #{used_con} out of #{max_con}" if pc >= config[:maxcrit].to_i
      warning "Max connections reached in MySQL: #{used_con} out of #{max_con}" if pc >= config[:maxwarn].to_i
      ok "Max connections is under limit in MySQL: #{used_con} out of #{max_con}"
    else
      critical "Max connections reached in MySQL: #{used_con} out of #{max_con}" if used_con >= config[:maxcrit].to_i
      warning "Max connections reached in MySQL: #{used_con} out of #{max_con}" if used_con >= config[:maxwarn].to_i
      ok "Max connections is under limit in MySQL: #{used_con} out of #{max_con}"
    end
rescue Mysql::Error => e
  critical "MySQL check failed: #{e.error}"
ensure
  db.close if db
  end
end
