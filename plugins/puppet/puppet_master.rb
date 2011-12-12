#!/usr/bin/env ruby
#
# Puppet Master Plugin
# ===
#
# This plugin checks to see if the Puppet Labs Puppet master is running
#
# Copyright 2011 James Turnbull
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

class PuppetMaster < Sensu::Plugin::Check::CLI::Procs

  check_name 'PUPPET MASTER'

  def run
    if find_proc_regex(get_procs, /puppetmasterd|puppet master/)
      ok 'Puppet master is running'
    else
      warning 'Puppet master is NOT running'
    end
  end
end
