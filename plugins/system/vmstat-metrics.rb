#! /usr/bin/env ruby
#  encoding: UTF-8
#   <script name>
#
# DESCRIPTION:
#   This plugin uses vmstat to collect basic system metrics, produces
#   Graphite formated output.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: socket
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2011 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class VMStat < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to .$parent.$child',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.vmstat"

  def convert_integers(values)
    values.each_with_index do |value, index|
      begin
        converted = Integer(value)
        values[index] = converted
        # #YELLOW
      rescue ArgumentError # rubocop:disable HandleExceptions
      end
    end
    values
  end

  def run
    result = convert_integers(`vmstat 1 2|tail -n1`.split(' '))
    timestamp = Time.now.to_i
    metrics = {
      procs: {
        waiting: result[0],
        uninterruptible: result[1]
      },
      memory: {
        swap_used: result[2],
        free: result[3],
        buffers: result[4],
        cache: result[5]
      },
      swap: {
        in: result[6],
        out: result[7]
      },
      io: {
        received: result[8],
        sent: result[9]
      },
      system: {
        interrupts_per_second: result[10],
        context_switches_per_second: result[11]
      },
      cpu: {
        user: result[12],
        system: result[13],
        idle: result[14],
        waiting: result[15]
      }
    }
    metrics.each do |parent, children|
      children.each do |child, value|
        output [config[:scheme], parent, child].join('.'), value, timestamp
      end
    end
    ok
  end
end
