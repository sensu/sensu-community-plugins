#!/usr/bin/env ruby

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
    # The first 7 columns as described in PROC(5)
    columns = ['user', 'nice', 'system', 'idle', 'iowait', 'irq', 'softirq']
    mpstat = {}
    i = 0
    until kstat[:"cpu#{i}"].nil? do
      mpstat[:"cpu#{i}"] = kstat[:"cpu#{i}"]
      total_cpu_time = 0
      columns.each do |column|
        total_cpu_time += kstat[:"cpu#{i}"][:"#{column}"]
      end
      mpstat[:"cpu#{i}"][:total] = total_cpu_time
      i +=1
    end
    return mpstat
  end

  def delta_cpu_metrics(baseline_cpus, sample_cpus)
    delta_cpus = {}
    baseline_cpus.each do | cpu, columns|
      delta_cpus[:"#{cpu}"] = {}
      columns.each do |task, time|
        delta_cpus[:"#{cpu}"][:"#{task}"] = sample_cpus[:"#{cpu}"][:"#{task}"] - time
      end
    end
    return delta_cpus
  end

  def run
    baseline_cpus = get_mpstats()
    # measure for a second then get the delta
    sleep(1)
    sample_cpus = get_mpstats()
    delta_cpus = delta_cpu_metrics(baseline_cpus, sample_cpus)
    delta_cpus.each_pair do |cpu, columns|
      # work out how long each cpu spent in jiffies
      columns.each_pair do |task, time|
        if task != "total"
          # Assumes architecture has jiffies as 1/100th of a second
          output "#{config[:scheme]}.#{cpu}.#{task}", time
        end
      end
    end
    ok
  end

end
