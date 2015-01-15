#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   ioping-metrics
#
# DESCRIPTION:
#   Push ioping stats into graphite
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
#   Copyright 2014 Mitsutoshi Aoe <maoe@foldr.in>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class IOPingMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :destination,
         short: '-d DEVICE|FILE|DIRECTORY',
         description: 'Destination device, file or directory',
         required: true

  option :name,
         short: '-n NAME',
         description: 'Name of the series',
         required: true

  option :count,
         short: '-c COUNT',
         description: 'Stop after count requests',
         default: 1,
         proc: proc(&:to_i)

  option :interval,
         short: '-i INTERVAL',
         description: 'Interval between requests in seconds',
         default: 1.0,
         proc: proc(&:to_f)

  option :cached,
         short: '-C',
         description: 'Use cached I/O',
         boolean: true,
         default: false

  option :direct,
         short: '-D',
         description: 'Use direct I/O',
         boolean: true,
         default: false

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: Socket.gethostname

  def run
    stats = ioping_stats(config[:server])
    critical 'Failed to get/parse ioping output' if stats.nil?
    stats.each do |key, value|
      output([config[:scheme], :ioping, config[:name], key].join('.'), value)
    end
    ok
  end

  def ioping_stats(_servers)
    options = []
    options << '-C' if config[:cached]
    options << '-D' if config[:direct]
    output = `ioping #{options.join(' ')} -c #{config[:count]} -i #{config[:interval]} #{config[:destination]}`
    parse_ioping(output)
  end

  def parse_ioping(str)
    stats = parse_0_8(str)
    stats = parse_0_6(str) if stats.nil?
    stats
  end

  NUMBER = /\d+(?:\.\d+)?/
  TIME_UNIT = /(?:us|ms|s|min|hour|day)/
  TIME_UNITS = {
    'us' => 1e-6,
    'ms' => 1e-3,
    's' => 1,
    'min' => 60,
    'hour' => 60 * 60,
    'day' => 24 * 60 * 60
  }
  # #YELLOW
  STATS_HEADER = /min\/avg\/max\/mdev/ # rubocop:disable RegexpLiteral

  def parse_0_6(str)
    value = /#{NUMBER}/
    sep = /\//
    pattern = /^#{STATS_HEADER} = (#{value})#{sep}(#{value})#{sep}(#{value})#{sep}(#{value}) (#{TIME_UNIT})$/
    str.scan(pattern).each do |scanned|
      min, avg, max, mdev, time_unit = scanned
      time_unit = TIME_UNITS[time_unit]
      if scanned.all? && time_unit
        return {
          min: min.to_f * time_unit,
          avg: avg.to_f * time_unit,
          max: max.to_f * time_unit,
          mdev: mdev.to_f * time_unit
        }
      end
    end
    nil
  end

  def parse_0_8(str)
    value = /(#{NUMBER}) (#{TIME_UNIT})\s/
    sep = /\/\s/
    pattern = /^#{STATS_HEADER} = #{value}#{sep}#{value}#{sep}#{value}#{sep}#{value}$/
    str.scan(pattern).each do |scanned|
      values = []
      units = []
      scanned.each_with_index do |val, idx|
        if idx.even?
          values[idx / 2] = val.to_f
        else
          units[idx / 2] = TIME_UNITS[val]
        end
      end

      if values.all? && units.all?
        return {
          min: values[0] * units[0],
          avg: values[1] * units[1],
          max: values[2] * units[2],
          mdev: values[3] * units[3]
        }
      end
    end
    nil
  end
end
