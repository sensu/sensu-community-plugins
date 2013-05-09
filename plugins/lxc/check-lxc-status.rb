#!/usr/bin/env ruby
# check-lxc-status
# ===
#
# This is a simple check script for Sensu to check the status of a Linux Container
#
# Requires "lxc" gem
#
# Examples:
#
#   check-lxc-status.rb -n name    => name of the container
#
#  Default lxc is "testdebian", change to if you dont want to pass host
# option
#  Author Deepak Mohan Dass   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'lxc'

class CheckLXCSTATUS < Sensu::Plugin::Check::CLI

  option :name,
    :short => '-n name',
    :default => "testdebian"

  def run
    conn = LXC.container("#{config[:name]}")
    if conn.exists?
      if conn.stopped?
        critical "container #{config[:name]} is Stopped"
      elsif conn.frozen?
        critical "container is #{config[:name]} in Frozen state"
      else
        ok "container  #{config[:name]} is Running"
      end
      else
      critical "container #{config[:name]} does not Exists"
    end
  end
end
