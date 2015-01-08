#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   ntpstats-metrics
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
#   Copyright 2014 Mitsutoshi Aoe <maoe@foldr.in>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class NtpStatsMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         description: 'Target host',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: Socket.gethostname

  def run
    # #YELLOW
    unless config[:host] == 'localhost'  # rubocop:disable IfUnlessModifier
      config[:scheme] = config[:host]
    end

    ntpstats = get_ntpstats(config[:host])
    critical "Failed to get ntpstats from #{config[:host]}" if ntpstats.empty?
    metrics = {
      ntpstats: ntpstats
    }
    metrics.each do |name, stats|
      stats.each do |key, value|
        output([config[:scheme], name, key].join('.'), value)
      end
    end
    ok
  end

  def get_ntpstats(host)
    key_pattern = Regexp.compile(%w(
      clk_jitter
      clk_wander
      frequency
      mintc
      offset
      stratum
      sys_jitter
      tc
    ).join('|'))
    num_val_pattern = /-?[\d]+(\.[\d]+)?/
    pattern = /(#{key_pattern})=(#{num_val_pattern}),?\s?/

    # #YELLOW
    `ntpq -c rv #{host}`.scan(pattern).reduce({}) do |hash, parsed| # rubocop:disable Style/EachWithObject
      key, val, fraction = parsed
      hash[key] = fraction ? val.to_f : val.to_i
      hash
    end
  end
end
