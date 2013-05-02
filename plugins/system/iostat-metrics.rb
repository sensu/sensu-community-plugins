#!/usr/bin/env /opt/sensu/embedded/bin/ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class IOStat < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.vmstat"

  def convert_floats(values)
    values.each_with_index do |value, index|
      begin
        converted = Float(value)
        values[index] = converted
      rescue ArgumentError
      end
    end
    values
  end

  def run
    iostat_metrics = %w[rrqm_s wrqm_s r_s w_s rkB_s wkB_s avgrq-sz avgqu-sz await r_await w_await svctm util]
    iostat_samples = {}
    `iostat -kx 1 2|tail -n3|head -n2`.split("\n").each do |dev_sample|
      dev = dev_sample.split(" ")
      iostat_samples[dev[0]] = convert_floats(dev[1..-1])
    end
    timestamp = Time.now.to_i

    iostat_samples.each do |device, values|
      0.upto(iostat_metrics.length) do |i|
        output [config[:scheme], device , iostat_metrics[i]].join("."), values[i], timestamp
      end
    end
    ok
  end

end
