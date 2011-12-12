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

require 'sensu/plugin/check/cli/procs'

class ChefClient < Sensu::Plugin::Check::CLI::Procs

  check_name 'chef_client'

  def run
    if find_proc(get_procs, 'chef-client')
      ok "Chef client daemon is running"
    else
      warning "Chef client daemon is NOT running"
    end
  end

end
