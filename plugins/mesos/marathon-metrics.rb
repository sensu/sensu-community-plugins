#! /usr/bin/env ruby
#
#   marathon-metrics
#
# DESCRIPTION:
#   This plugin extracts the 'count' metrics from a marathon server
#
# OUTPUT:
#    metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#   gem: socket
#   gem: json
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2015, Tom Stockton (tom@stocktons.org.uk)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'socket'
require 'json'

class MarathonMetrics < Sensu::Plugin::Metric::CLI::Graphite
  SKIP_ROOT_KEYS = %w(version)
  option :scheme,
         description: 'Metric naming scheme',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.marathon"

  option :server,
         description: 'Marathon Host',
         short: '-h SERVER',
         long: '--host SERVER',
         default: 'localhost'

  def run
    r = RestClient::Resource.new("http://#{config[:server]}:8080/metrics", timeout: 5).get
    all_metrics = JSON.parse(r)
    metric_groups = all_metrics.keys - SKIP_ROOT_KEYS
    metric_groups.each do |metric_groups_key|
      all_metrics[metric_groups_key].each do |metric_key, metric_value|
        metric_value.each do |metric_hash_key, metric_hash_value|
          output([config[:scheme], metric_groups_key, metric_key, metric_hash_key].join('.'), metric_hash_value) \
            if metric_hash_value.is_a?(Numeric) && metric_hash_key == 'count'
        end
      end
    end
    ok
  rescue Errno::ECONNREFUSED
    critical 'Marathon is not responding'
  rescue RestClient::RequestTimeout
    critical 'Marathon Connection timed out'
  end
end
