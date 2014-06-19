#!/usr/bin/env ruby
#
# System Load Stats Plugin
# ===
#
# Load per processor
# ------------------
#
# Optionally, with `--load-per-proc`, this plugin will calculate load per
# processor from the raw load average by dividing load average by the number
# of processors.
#
# The number of CPUs is determined by reading `/proc/cpuinfo`. This makes the
# feature Linux specific. Other OSs can be supported by adding OS # detection
# and a method to determine the number of CPUs.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

if RUBY_VERSION < '1.9.0'
  require 'bigdecimal'

  class Float
    def round(val = 0)
       BigDecimal.new(self.to_s).round(val).to_f
    end
  end
end

class LoadAverage
  
  def initialize(per_core = false)
    @cores = per_core ? cpu_count : 1
    @avg = File.read('/proc/loadavg').split.take(3).map { |a|
      (a.to_f / @cores).round(2)
    } rescue nil # rubocop:disable RescueModifier
  end
  
  def cpu_count
    `grep -sc ^processor /proc/cpuinfo`.to_i rescue 0
  end
  
  def failed?
    @avg.nil? || @cores.zero?
  end
  
  def exceed?(thresholds)
    @avg.zip(thresholds).any? {|a, t| a > t }
  end
  
  def to_s
    @avg.join(', ')
  end
  
  def [](y)
    @avg[y]
  end
  
end

class LoadStat < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  option :per_core,
    :description => 'Divide load average results by cpu/core count',
    :short => "-p",
    :long => "--per-core",
    :boolean => true,
    :default => false

  def run
    timestamp = Time.now.to_i
    avg = LoadAverage.new(config[:per_core])
    metrics = {
      :load_avg => {
        :one => avg[0],
        :five => avg[1],
        :fifteen => avg[2]
      }
    }

    metrics.each do |parent, children|
      children.each do |child, value|
        output [config[:scheme], parent, child].join("."), value, timestamp
      end
    end
    ok
  end

end
