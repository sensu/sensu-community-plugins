#!/usr/bin/env ruby
#
# Chef Client Plugin
# ===
#
# This plugin checks to see if the OpsCode Chef client daemon is running
#
# Copyright 2011 Sonian, Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu/plugin/check/cli'

class ChefClient < Sensu::Plugin::Check::CLI

  check_name 'chef-client'

  def get_procs
    `which tasklist`; $? == 0 ? `tasklist` : `ps aux`
  end

  def find_proc(procs, proc)
    procs.split("\n").find {|ln| ln.include?(proc) }
  end

  def run
    if find_proc(get_procs, 'chef-client')
      ok 'Chef client daemon is running'
    else
      warning 'Chef client daemon is NOT running'
    end
  end

end
