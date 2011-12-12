#!/usr/bin/env ruby
#
# Puppet Agent Plugin
# ===
#
# This plugin checks to see if the Puppet Labs Puppet agent is running
#
# Copyright 2011 James Turnbull
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu/plugin/check/cli/procs'

class PuppetAgent < Sensu::Plugin::Check::CLI::Procs

  check_name 'PUPPET AGENT'

  def run
    if find_proc_regex(get_procs, /puppetd|puppet agent/)
      ok 'Puppet agent is running'
    else
      warning 'Puppet agent is NOT running'
    end
  end
end
