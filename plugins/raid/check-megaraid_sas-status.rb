#!/usr/bin/env ruby
#
# MegaCli RAID status check
# ===
#
# Checks the status of all virtual drives of a particular controller
# 
# MegaCli/MegaCli64 requires root access
#
# Copyright 2014 Magnus Hagdorn <magnus.hagdorn@ed.ac.uk>
# The University of Edinburgh
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckMegraRAID < Sensu::Plugin::Check::CLI
  option :megaraidcmd,
         :description => "the MegaCli executable",
         :short => '-c CMD',
         :long => '--command CMD',
         :default => '/opt/MegaRAID/MegaCli/MegaCli64'
  option :controller,
         :description => "the controller to query",
         :short => '-C ID',
         :long => '--controller ID',
         :proc => proc {|a| a.to_i },
         :default => 0
  
  def run
    haveError=false
    error=''
    # get number of virtual drives
    `#{config[:megaraidcmd]} -LDGetNum -a#{config[:controller]} `
    for i in 0..$?.exitstatus-1
      # and check them in turn
      stdout = `#{config[:megaraidcmd]} -LDInfo -L#{i} -a#{config[:controller]} `
      if not Regexp.new('State\s*:\s*Optimal').match(stdout)
        error << 'virtual drive %d: %s '%[i,stdout[/State\s*:\s*.*/].split(':')[1]]
        haveError = true
      end
    end

    if haveError
      critical error
    else
      ok
    end
  end
end
