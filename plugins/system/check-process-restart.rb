#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   check-process-restart
#
# DESCRIPTION:
#   This will check if a running process requires a restart if a
#   dependent package/library has changed (i.e upgraded)
#
# OUTPUT:
#   plain text
#   Defaults: CRITICAL if 2 or more process require a restart
#             WARNING if 1 process requires a restart
#
# PLATFORMS:
#   Linux (Debian based distributions)
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   deb: debian-goodies
#
# USAGE:
#   check-process-restart.rb # Uses defaults
#   check-process-restart.rb -w 2 -c 5
#
# NOTES:
#   This will only work on Debian based distributions and requires the
#   debian-goodies package.
#
#   Also make sure the user "sensu" can sudo without password
#
# LICENSE:
#   Yasser Nabi yassersaleemi@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'json'
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'English'

# Use to see if any processes require a restart
class CheckProcessRestart < Sensu::Plugin::Check::CLI
  option :warn,
         short: '-w WARN',
         default: 1

  option :crit,
         short: '-c CRIT',
         default: 2

  CHECK_RESTART = '/usr/sbin/checkrestart'

  # Set path for the checkrestart script
  def initialize
    super
  end

  # Check if we can run checkrestart script
  # Return: Boolean
  def checkrestart?
    File.exist?('/etc/debian_version') && File.exist?(CHECK_RESTART)
  end

  # Run checkrestart and parse process(es) and pid(s)
  # Return: Hash
  def run_checkrestart
    checkrestart_hash = { found: '', pids: [] }

    out = `sudo #{CHECK_RESTART} 2>&1`
    if $CHILD_STATUS.to_i != 0
      checkrestart_hash[:found] = "Failed to run checkrestart: #{out}"
    else
      out.lines do |l|
        m = /^Found\s(\d+)/.match(l)
        if m
          checkrestart_hash[:found] = m[1]
        end

        m = /^\s+(\d+)\s+([ \w\/\-\.]+)$/.match(l)
        if m
          checkrestart_hash[:pids] << { m[1] => m[2] }
        end
      end
    end
    checkrestart_hash
  end

  # Main run method for the check
  def run
    unless checkrestart?
      unknown "Can't seem to find checkrestart. This check only works in a Debian based distribution and you need debian-goodies package installed"
    end

    checkrestart_out = run_checkrestart
    if /^Failed/.match(checkrestart_out[:found])
      unknown checkrestart_out[:found]
    end
    message JSON.generate(checkrestart_out)
    found = checkrestart_out[:found].to_i
    warning if found >= config[:warn] && found < config[:crit]
    critical if found >= config[:crit]
    ok
  end
end
