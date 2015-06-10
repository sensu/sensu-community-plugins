#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   metrics-chrony
#
# DESCRIPTION:
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
#   Copyright 2015 Mitsutoshi Aoe <maoe@foldr.in>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'socket'

class ChronyMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         description: 'Chrony host',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: Socket.gethostname

  def run
    config[:scheme] = config[:host] unless config[:host] == 'localhost'

    tracking = get_tracking(config)
    critical "Failed to get chrony stats from #{config[:host]}" if tracking.empty?
    metrics = {
      tracking: tracking
    }
    metrics.each do |name, stats|
      stats.each do |key, value|
        output([config[:scheme], 'chrony', name, key].join('.'), value)
      end
    end
    ok
  end

  def get_tracking(config)
    `chronyc tracking`.each_line.reduce({}) do |r, line|
      key, value = line.split(/\s*:\s*/)
      next(r) if value.nil?
      key = snakecase(key)
      matches = value.match(/^[+-]?\d+(\.\d+)?\s/) or next(r)
      digits = matches[0] or next(r)
      number = digits.to_f
      number = - number if /slow/ =~ value
      r[key] = number
      r
    end
  end

  def snakecase(str)
    str.downcase.gsub(/ /, '_').gsub(/[()]/, '')
  end
end
