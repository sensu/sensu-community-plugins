#!/usr/bin/env ruby
#
# Simple Sensu File Exists Plugin
# ===
#
# Sometimes you just need a simple way to test if your alerting is functioning
# as you've designed it. This test plugin accomplishes just that. But it can
# also be set to check for the existance of any file (provided you have
# read-level permissions for it)
#
# By default it looks in your /tmp folder and looks for the files CRITICAL,
# WARNING or UNKNOWN. If it sees that any of those exists it fires off the
# corresponding status to sensu. Otherwise it fires off an "ok".
#
# This allows you to fire off an alert by doing something as simple as:
# touch /tmp/CRITICAL
#
# And then set it ok again with:
# rm /tmp/CRITICAL
#
# Copyright 2013 Mike Skovgaard <mikesk@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckFileExists < Sensu::Plugin::Check::CLI

  option :critical,
    :short => '-c CRITICAL_FILE',
    :default => '/tmp/CRITICAL'

  option :warning,
    :short => '-w WARNING_FILE',
    :default => '/tmp/WARNING'

  option :unknown,
    :short => '-u UNKNOWN_FILE',
    :default => '/tmp/UNKNOWN'

  def run
    if config[:critical] && File.exists?(config[:critical])
      critical "#{config[:critical]} exists!"
    elsif config[:warning] && File.exists?(config[:warning])
      warning "#{config[:warning]} exists!"
    elsif config[:unknown] && File.exists?(config[:unknown])
      unknown "#{config[:unknown]} exists!"
    else
      ok "No test files exist"
    end
  end

end
