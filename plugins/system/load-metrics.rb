#!/usr/bin/env ruby
#
# System Load Stats Plugin
# ===
#
# This plugin uses uptime to collect load metrics
# Basically copied from sensu-community-plugins/plugins/system/vmstat-metrics.rb
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

  def convert_integers(values)
    values.each_with_index do |value, index|
      begin
        converted = Integer(value)
        values[index] = converted
      rescue ArgumentError
      end
    end
    values
  end

  def run
    #result = convert_integers(`vmstat 1 2|tail -n1`.split(" "))
    result = `uptime`.gsub(',','').split(' ') 
    result = result[-3..-1]
    
    timestamp = Time.now.to_i
    metrics = {
      :load_avg => {
         :one => result[0],
         :five => result[1],
         :fifteen => result[2]
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
