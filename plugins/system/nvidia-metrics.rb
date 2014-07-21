#!/usr/bin/env ruby
#
# NVidia Graphics Card Metric Plugin
# ===
#
# This plugin uses nvidia-smi to collect basic metrics, produces
# Graphite formated output.
#
# Copyright 2014 Cedric <cedric.grun@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# PLATFORMS:
#   linux
#
# DEPENDENCIES : nvidia-smi
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class EntropyGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.nvidia"

  def run
    metrics = {}
    keys = ['temperature.gpu', 'fan.speed', 'memory.used', 'memory.total', 'memory.free']
    keys.each do |key|
      metrics[key] = `nvidia-smi --query-gpu=#{key} --format=csv,noheader`.match(/\d+\.?\d*/).to_s
    end

    timestamp = Time.now.to_i

    metrics.each do |key, value|
      output [config[:scheme], key].join("."), value, timestamp
    end

    ok
  end

end
