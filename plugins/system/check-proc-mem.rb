#!/usr/bin/env ruby
#  encoding: UTF-8
#   check-proc-mem.rb
#
# DESCRIPTION:
#   Check the amount of memory a process is using
#
#   Can be on percentage or MB of ram by default
#
# OUTPUT:
#  Critical/OK
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Benjamin Kaehne <ben.kaehne@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class ProcMem < Sensu::Plugin::Check::CLI
  option :process,
         description: 'Process',
         short: '-p PROCESS',
         long: '--process PROCESS',
         description: 'Process to monitor',
         default: false

  option :megabytesmem,
         short: '-m MEGABYTES',
         long: '--mem MEGATBYTE',
         description: 'Default: Number of megabytes used',
         proc: proc(&:to_i),
         default: 8192

  option :percent,
         description: 'Percent',
         short: '-e PERCENT',
         long: '--percent PERCENT',
         description: 'Optional: Percent of machine total memory inc swap to monitor',
         proc: proc(&:to_f),
         default: false

  def systemmem
    `free -m | grep Mem`.split[1].to_i + `free -m | grep Swap`.split[1].to_i
  end

  def process
    `pidof #{config[:process]}`.chomp
  end

  def processmem
    `pmap -x #{process} | grep total`.split[2].to_i / 1024
  end

  def procpercent
    processmem / systemmem.to_f * 100
  end

  def run
    if config[:percent]
      message "#{config[:process]} is taking up #{procpercent.round(2)}% of memory"
      if procpercent >= config[:percent]
        critical
      else
        ok
      end
    else
      message "#{config[:process]} is taking up #{processmem}MB of memory"
      if processmem >= config[:megabytesmem]
        critical
      else
        ok
      end
    end
  end
end
