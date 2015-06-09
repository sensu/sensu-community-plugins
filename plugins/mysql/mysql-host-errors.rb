#! /usr/bin/env ruby
#
#   MySQL Host Error Count Plugin: mysql-host-errors.rb
#
# DESCRIPTION:
#   This plugin counts the number of hosts violating a certain error field from the performance_schema.host_cache table in MySQL.
#   By default, it checks the count of hosts with COUNT_HOST_BLOCKED_ERRORS > 0, but there are 22 or so other fields that can be checked by specifying the field on the command line.
#   The script specifically checks the # of hosts violating the check, instead of whether any individual host's error count exceeds. This is simply due to the fact that any host with non-zero count is generally considered bad.
#
# OUTPUT:
#   Text containing human readable result of check.
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   mysql
#
# USAGE:
#   mysql-host-errors.rb -e COUNT_HOST_BLOCKED_ERRORS -c 1
#
# NOTES:
#   If this alert triggers, you simply would run "FLUSH hosts" in mysql to fix the error.
#   It was also decided not to provide an option to automatically call "FLUSH hosts" to fix the issue.
#
# LICENSE:
#   Steve Frank <lardcanoe@gmail.com>
#
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'mysql'

class CheckMySQLHostErrors < Sensu::Plugin::Check::CLI
  option :user,
         description: 'MySQL User',
         short: '-u USER',
         long: '--user USER',
         default: 'root'

  option :password,
         description: 'MySQL Password',
         short: '-p PASS',
         long: '--password PASS'

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

  option :error,
         description: 'Field from performance_schema.host_cache to count',
         short: '-e ERROR',
         long: '--error ERROR',
         default: 'COUNT_HOST_BLOCKED_ERRORS'

  option :maxwarn,
         description: "Number of hosts upon which we'll issue a warning",
         short: '-w NUMBER',
         long: '--warnnum NUMBER',
         default: 1

  option :maxcrit,
         description: "Number of hosts upon which we'll issue an alert",
         short: '-c NUMBER',
         long: '--critnum NUMBER',
         default: 1

  def run
    critical 'Invalid error param specified.' unless config[:error] =~ /^[A-Z_]+$/

    db = Mysql.real_connect(config[:hostname], config[:user], config[:password], config[:database], config[:port].to_i, config[:socket])

    host_count = db
        .query("SELECT count(*) as Value FROM performance_schema.host_cache WHERE #{config[:error]} > 0")
        .fetch_hash
        .fetch('Value')
        .to_i

    critical "Max host error count for #{config[:error]} reached in MySQL #{config[:hostname]}: #{host_count}" if host_count >= config[:maxcrit].to_i
    warning  "Max host error count for #{config[:error]} reached in MySQL #{config[:hostname]}: #{host_count}" if host_count >= config[:maxwarn].to_i
    ok       "Max host error count for #{config[:error]} is under limit in MySQL #{config[:hostname]}: #{host_count}"
  rescue Mysql::Error => e
    critical "MySQL host error check for #{config[:error]} failed on #{config[:hostname]}: #{e.error}"
  ensure
    db.close if db
  end
end
