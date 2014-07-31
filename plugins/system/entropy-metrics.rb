#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class EntropyGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
      :description => "Metric naming scheme, text to prepend to metric",
      :short => "-s SCHEME",
      :long => "--scheme SCHEME",
      :default => "#{Socket.gethostname}.entropy"

  def run
    File.open("/proc/sys/kernel/random/entropy_avail", "r").each_line do |line|
      entropy = line.strip.split(/\s+/).shift
      output "#{config[:scheme]}", entropy
    end
    ok
  end

end
