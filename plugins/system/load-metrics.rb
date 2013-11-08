#!/usr/bin/env ruby
#
# System Load Stats Plugin
# ===
#
# This plugin uses uptime to collect load metrics
# Basically copied from sensu-community-plugins/plugins/system/vmstat-metrics.rb
#
# Load per processor
# ------------------
#
# Optionally, with `--load-per-proc`, this plugin will calculate load per
# processor from the raw load average by dividing by the number of processors.
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

class LoadStat < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  option :load_per_processor,
    :description => "Calculate load per processor instead of raw load averages.",
    :long => "--load-per-proc",
    :boolean => true,
    :default => false

  def number_of_cores
    @cores ||= File.readlines('/proc/cpuinfo').select { |l| l =~ /^processor\s+:/ }.count
  end

  def run
    result = `uptime`.gsub(',', '').split(' ')
    result = result[-3..-1]

    timestamp = Time.now.to_i
    if config[:load_per_processor]
      metrics = {
        :load_avg => {
          :one => (result[0].to_f / number_of_cores).round(2),
          :five => (result[1].to_f / number_of_cores).round(2),
          :fifteen => (result[2].to_f / number_of_cores).round(2)
        }
      }
    else
      metrics = {
        :load_avg => {
           :one => result[0],
           :five => result[1],
           :fifteen => result[2]
         }
      }
    end

    metrics.each do |parent, children|
      children.each do |child, value|
        output [config[:scheme], parent, child].join("."), value, timestamp
      end
    end
    ok
  end

end
