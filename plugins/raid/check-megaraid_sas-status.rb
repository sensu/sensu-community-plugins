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
require 'English'

class CheckMegraRAID < Sensu::Plugin::Check::CLI
  option :megaraidcmd,
         description: 'the MegaCli executable',
         short: '-c CMD',
         long: '--command CMD',
         default: '/opt/MegaRAID/MegaCli/MegaCli64'
  option :controller,
         description: 'the controller to query',
         short: '-C ID',
         long: '--controller ID',
         proc: proc(&:to_i),
         default: 0

  def run
    have_error = false
    error = ''
    # get number of virtual drives
    `#{config[:megaraidcmd]} -LDGetNum -a#{config[:controller]} `
    (0..$CHILD_STATUS.exitstatus - 1).each do |i|
      # and check them in turn
      stdout = `#{config[:megaraidcmd]} -LDInfo -L#{i} -a#{config[:controller]} `
      unless Regexp.new('State\s*:\s*Optimal').match(stdout)
        error = sprintf '%svirtual drive %d: %s ', error, i, stdout[/State\s*:\s*.*/].split(':')[1]
        have_error = true
      end
    end

    if have_error
      critical error
    else
      ok
    end
  end
end
