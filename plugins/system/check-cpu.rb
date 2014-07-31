#!/usr/bin/env ruby
#
# Check CPU Plugin
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckCPU < Sensu::Plugin::Check::CLI

  option :warn,
    :short => '-w WARN',
    :proc => proc {|a| a.to_f },
    :default => 80

  option :crit,
    :short => '-c CRIT',
    :proc => proc {|a| a.to_f },
    :default => 100

  option :sleep,
    :long => '--sleep SLEEP',
    :proc => proc {|a| a.to_f },
    :default => 1

  [:user, :nice, :system, :idle, :iowait, :irq, :softirq, :steal, :guest].each do |metric|
    option metric,
      :long  => "--#{metric}",
      :description => "Check cpu #{metric} instead of total cpu usage",
      :boolean => true,
      :default => false
  end

  def get_cpu_stats
    File.open("/proc/stat", "r").each_line do |line|
      info = line.split(/\s+/)
      name = info.shift
      return info.map{|i| i.to_f} if name.match(/^cpu$/)
    end
  end

  def run
    metrics = [:user, :nice, :system, :idle, :iowait, :irq, :softirq, :steal, :guest]

    cpu_stats_before = get_cpu_stats
    sleep config[:sleep]
    cpu_stats_after = get_cpu_stats

    # Some kernels don't have a 'guest' value (RHEL5).
    metrics = metrics.slice(0, cpu_stats_after.length)

    cpu_total_diff = 0.to_f
    cpu_stats_diff = []
    metrics.each_index do |i|
      cpu_stats_diff[i] = cpu_stats_after[i] - cpu_stats_before[i]
      cpu_total_diff += cpu_stats_diff[i]
    end

    cpu_stats = []
    metrics.each_index do |i|
      cpu_stats[i] = 100*(cpu_stats_diff[i]/cpu_total_diff)
    end

    cpu_usage = 100*(cpu_total_diff - cpu_stats_diff[3])/cpu_total_diff
    checked_usage = cpu_usage

    self.class.check_name 'CheckCPU TOTAL'
    metrics.each do |metric|
      if config[metric]
        self.class.check_name "CheckCPU #{metric.to_s.upcase}"
        checked_usage = cpu_stats[metrics.find_index(metric)]
      end
    end

    msg = "total=#{cpu_usage.round(2)}"
    cpu_stats.each_index {|i| msg += " #{metrics[i]}=#{cpu_stats[i].round(2)}"}

    message msg

    critical if checked_usage > config[:crit]
    warning if checked_usage > config[:warn]
    ok
  end

end
