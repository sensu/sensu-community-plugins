#! /usr/bin/env ruby
#
#   check-lxc-memstat
#
# DESCRIPTION:
#   This is a simple check script for Sensu to check out the LXC's memory usage
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: lxc
#
# USAGE:
#   check-lxc-memstat.rb -n name -w warn  -c critical
#
#   check-lxc-memstat.rb -n testdebian -w 80 -c 90
#
#   Default lxc is "testdebian", change to if you dont want to pass host
#   option
#
# NOTES:
#
# LICENSE:
#   Deepak Mohan Dass   <deepakmdass88@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'lxc'

class CheckLXCMemstat < Sensu::Plugin::Check::CLI
  option :name,
         short: '-n name',
         default: 'testdebian'

  option :warning,
         short: '-w warning',
         default: '80'

  option :critical,
         short: '-c critical',
         default: '90'

  def run
    conn = LXC.container("#{config[:name]}")
    if conn.exists?
      if conn.running?
        used = conn.memory_usage
        max = conn.memory_limit
        if used > (max * ("#{config[:critical]}".to_f / 100))
          critical "container #{config[:name]} memory usage crossed the critical limit"
        elsif used > (max * ("#{config[:warning]}".to_f / 100))
          warning "container #{config[:name]} memory usage crossed the warning limit"
        else
          ok "container #{config[:name]} memory usage is normal"
        end
      else
        critical "container #{config[:name]} is not running"
      end
    else
      critical "container #{config[:name]} does not exists"
    end
  end
end
