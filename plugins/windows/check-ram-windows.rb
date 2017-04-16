#!/usr/bin/env ruby
#
# Check percent of used RAM
#
# Drew Rogers
# Copyright 2015 <drogers@chariotsolutions.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckRam < Sensu::Plugin::Check::CLI

  option :warn,
    :short => '-w PERCENT',
    :proc => proc {|a| a.to_i },
    :default => 85

  option :crit,
    :short => '-c PERCENT',
    :proc => proc {|a| a.to_i },
    :default => 95

  def getRamUsage
    tempArr1=Array.new
    tempArr2=Array.new
    timestamp = Time.now.utc.to_i
    IO.popen("typeperf -sc 1 \"Memory\\Available bytes\" ") { |io| io.each { |line| tempArr1.push(line) } }
    temp = tempArr1[2].split(",")[1]
    ramAvailableInBytes = temp[1, temp.length - 3].to_f
    IO.popen("wmic OS get TotalVisibleMemorySize /Value") { |io| io.each { |line| tempArr2.push(line) } }
    totalRam = tempArr2[4].split('=')[1].to_f
    totalRamInBytes = totalRam*1000.0
    ramUsePercent=(totalRamInBytes - ramAvailableInBytes)*100.0/(totalRamInBytes)
    [ramUsePercent.round(2), timestamp]
  end

  def run

    values = getRamUsage
    if values[0] >= config[:crit]
      critical "RAM is at #{values[0]}%"
    elsif values[0] >= config[:warn]
      warning "RAM is at #{values[0]}%"
    else
      ok "RAM is at #{values[0]}%"
    end
  end
end
