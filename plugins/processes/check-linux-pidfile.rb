#!/usr/bin/env ruby
# check-linux-pidfile
# ===
#
# This is a simple pidfile check script for Sensu.  It will read the
# file specified and then look for a process matching the pid.  It can
# optionally match against a user provided string.
#
# Examples:
#
#   check-linux-pid-file -p /var/run/foo.pid
#   check-linux-pid-file -p /var/run/sshd.pid -m ssd
#
#  Author: S. Zachariah Sprackett <zac@sprackett.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'pathname'

class CheckLinuxPidFile < Sensu::Plugin::Check::CLI
  option :pidfile,
    :short       => '-p PIDFILE',
    :description => 'Path to pidfile'
  option :match_string,
    :short       => '-m MATCH_STRING',
    :description => 'String to match in cmdline'

  def run
    unknown "No pid file specified" unless config[:pidfile]
    begin
      pid = File.read(config[:pidfile])
    rescue => e
      critical "Unable to read pid file (#{e})"
    end
    pid.chomp!
    unless pid.to_s.match(/^[\d]+$/)
      critical "Pid file #{config[:pidfile]} doesn't contain a pid"
    end
    begin
      path = File.new "/proc/#{pid}/cmdline"
      cmdline = path.read.split("\000").join
    rescue => e
      critical "Failed to read (#{e})"
    end
    if config[:match_string]
      unless cmdline.include?(config[:match_string])
        critical "cmdline for pid #{pid} did not contain #{config[:match_string]}: #{cmdline}"
      end
    end
    ok
  end
end
