#!/usr/bin/env ruby
#
# mpstat style output for each CPU on system
# ===
#
# Uses the linux/kstat rubygem to do the hard work in /proc/stat
# includes individual cpu and overall cpu usage

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'linux/kstat'

class CpuGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.cpu"

  def get_mpstats
    kstat = Linux::Kstat.new
    mpstat = {}
    i = ""
    until kstat[:"cpu#{i}"].nil? do
      mpstat[:"cpu#{i}"] = kstat[:"cpu#{i}"]
      if i == ""
        i = 0
      else
        i +=1
      end
    end
    mpstat
  end

  def delta_cpu_metrics(baseline_cpus, sample_cpus)
    delta_cpus = {}
    baseline_cpus.each do | cpu, columns|
      delta_cpus[:"#{cpu}"] = {}
      columns.each do |task, time|
        delta_cpus[:"#{cpu}"][:"#{task}"] = sample_cpus[:"#{cpu}"][:"#{task}"] - time
      end
    end
    delta_cpus
  end

  def run
    baseline_cpus = get_mpstats
    # measure for a second then get the deltas in jiffies
    sleep(1)
    sample_cpus = get_mpstats
    delta_cpus = delta_cpu_metrics(baseline_cpus, sample_cpus)
    cpu_count = sample_cpus.length - 1
    delta_cpus.each_pair do |cpu, columns|
      # assumes architecture's jiffie is 1/100th of a second
      columns.each_pair do |task, time|
        if "#{cpu}" == "cpu"
          time = time/cpu_count
        end
        output "#{config[:scheme]}.#{cpu}.#{task}", time
      end
    end
    ok
  end

end
