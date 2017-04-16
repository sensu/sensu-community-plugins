#!/usr/bin/env ruby
# Check usage ram for Windows
# ===
#
# Referred to ram-usage-windows.rb.(Thank you!)
# Tested on Windows 2012RC2.
#
# Yohei Kawahara <inokara@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckRamUsageWindows < Sensu::Plugin::Check::CLI

  option :warning,
    :short => '-w WARNING',
    :default => 85

  option :critical,
    :short => '-c CRITICAL',
    :default => 95

  def getRamUsage
    tempArr1=Array.new
    tempArr2=Array.new
    IO.popen("typeperf -sc 1 \"Memory\\Available bytes\" ") { |io| io.each { |line| tempArr1.push(line) } }
    temp = tempArr1[2].split(",")[1]
    ramAvailableInBytes = temp[1, temp.length - 3].to_f
    IO.popen("wmic OS get TotalVisibleMemorySize /Value") { |io| io.each { |line| tempArr2.push(line) } }
    totalRam = tempArr2[4].split('=')[1].to_f
    totalRamInBytes = totalRam*1000.0
    ramUsePercent=(totalRamInBytes - ramAvailableInBytes)*100.0/(totalRamInBytes)
    ramUsePercent.round(2)
  end

  def run
    ram_usage = getRamUsage
    critical "RAM at #{ram_usage}%" if ram_usage > config[:critical].to_f
    warning "RAM at #{ram_usage}%" if ram_usage > config[:warning].to_f
    ok "RAM at #{ram_usage}%"
  end
end
