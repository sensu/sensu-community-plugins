#! /usr/bin/env ruby
#
#   check-chef-server
#
# DESCRIPTION:
#   This plugin uses Chef Servers's `chef-server-ctl` to check to see if
#   any component of the chef server is not running.  This plugin needs
#   to be run with elevated privileges (sudo) or it will fail with unknown
#   state.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   Chef Server
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Returns CRITICAL if any of the chef-server processes are in a 'fail' or 'down' state
#
# LICENSE:
#   Tim Smith  tim@cozy.co
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckChefServer < Sensu::Plugin::Check::CLI
  def run
    # chef-server-ctl must be run with elevated privs. fail if we're not uid 0
    if Process.uid != 0
      unknown('check-chef-server must be run with elevated privileges so that chef-server-ctl can be executed')
    else
      status = `/usr/bin/chef-server-ctl status`
      failed_processes = []
      status.each_line do |proc|
        if proc.match('^(fail|down|warning)')
          failed_processes << proc.match('^(fail|down|warning):\s+([a-z-]+)')[2]
        end
      end
      if failed_processes.count > 0
        critical("chef-server service(s): #{failed_processes.join(', ')} #{failed_processes.count == 1 ? 'is' : 'are'} failed, down, or in warning state")
      else
        ok
      end
    end
  end
end
