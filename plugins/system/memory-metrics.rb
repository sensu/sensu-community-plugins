#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class MemoryGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.memory"

  def run
    # Metrics borrowed from hoardd: https://github.com/coredump/hoardd

    mem = {}
    File.open("/proc/meminfo", "r").each_line do |line|
      mem['total']     = line.split(/\s+/)[1].to_i * 1024 if line.match(/^MemTotal/)
      mem['free']      = line.split(/\s+/)[1].to_i * 1024 if line.match(/^MemFree/)
      mem['buffers']   = line.split(/\s+/)[1].to_i * 1024 if line.match(/^Buffers/)
      mem['cached']    = line.split(/\s+/)[1].to_i * 1024 if line.match(/^Cached/)
      mem['swapTotal'] = line.split(/\s+/)[1].to_i * 1024 if line.match(/^SwapTotal/)
      mem['swapFree']  = line.split(/\s+/)[1].to_i * 1024 if line.match(/^SwapFree/)
    end

    mem['swapUsed'] = mem['swapTotal'] - mem['swapFree']
    mem['used'] = mem['total'] - mem['free']
    mem['usedWOBuffersCaches'] = mem['used'] - (mem['buffers'] + mem['cached'])
    mem['freeWOBuffersCaches'] = mem['free'] + (mem['buffers'] + mem['cached'])

    mem.each do |k, v|
      output "#{config[:scheme]}.#{k}", v
    end

    ok
  end

end
