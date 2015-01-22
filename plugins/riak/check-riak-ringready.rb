#!/usr/bin/env ruby
#
# Check Riak Ring Status Plugin
# ===
#
# Runs 'riak-admin ringready' to check that all nodes agree on ring
#
# riak-admin requires root permissions.
#
# Create a file named /etc/sudoers.d/riak-admin with this line inside:
# sensu ALL=(ALL) NOPASSWD: /usr/sbin/riak-admin ringready
#
# Copyright 2014 Alexander Bulimov <lazywolf0@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'open3'

class CheckRiakRingStatus < Sensu::Plugin::Check::CLI
  def execute(cmd)
    captured_stdout = ''
    exit_status = Open3.popen2e(ENV, cmd) do |stdin, stdout, wait_thr|
      stdin.close
      captured_stdout = stdout.read
      wait_thr.value
    end
    [exit_status, captured_stdout]
  end

  def run
    exit_status, message = execute 'sudo -n -k riak-admin ringready'
    # #YELLOW
    if exit_status.success? # rubocop:disable IfUnlessModifier
      ok message if /^TRUE/ =~ message
    end
    critical message
  end
end
