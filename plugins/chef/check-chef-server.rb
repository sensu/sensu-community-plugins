#!/usr/bin/env ruby
#
# Check for chef-server health using chef-server-ctl
# ===
#
# DESCRIPTION:
#   This plugin uses Chef Servers's `chef-server-ctl` to check to see
#   if any component of the chef server is not running
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   Chef server
#
# OUTPUT:
#   Plain-text.
#   Returns CRITICAL if any of the chef-server processes are in a 'fail' or 'down' state
#
# AUTHORS:
#   Tim Smith tim@cozy.co
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckChefServer < Sensu::Plugin::Check::CLI

  def run
    status = `/usr/bin/chef-server-ctl status`
    failed_processes = []
    status.each_line do |proc|
      if proc.match('^(fail|down)')
        failed_processes << proc.match('^(fail|down):\s+([a-z-]+)')[2]
      end
    end
    if failed_processes.count > 0
      critical("chef-server services: #{failed_processes.join(', ')} are not running")
    else
      ok
    end
  end
end
