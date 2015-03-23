#! /usr/bin/env ruby
#
#   jenkins-metrics
#
# DESCRIPTION:
#   This plugin extracts the metrics from a Jenkins Master with Metrics plugin installed
#   Anonymous user must have Metrics permissions.
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
#   Copyright 2015, Cornel Foltea (cornel.foltea@gmail.com)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'socket'
require 'json'

class JenkinsMetrics < Sensu::Plugin::Metric::CLI::Graphite
  SKIP_ROOT_KEYS = %w(version)

  option :scheme,
         description: 'Metric naming scheme',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.jenkins"

  option :server,
         description: 'Jenkins Host',
         short: '-s SERVER',
         long: '--server SERVER',
         default: 'localhost'

  option :port,
         description: 'Jenkins Port',
         short: '-p PORT',
         long: '--port PORT',
         default: '8080'

  option :uri,
         description: 'Jenkins Metrics URI',
         short: '-u URI',
         long: '--uri URI',
         default: '/metrics/currentUser/metrics'

  def run
    begin
      r = RestClient::Resource.new("http://#{config[:server]}:#{config[:port]}#{config[:uri]}", timeout: 5).get
      all_metrics = JSON.parse(r)
      metric_groups = all_metrics.keys - SKIP_ROOT_KEYS
      metric_groups.each do |metric_groups_key|
        all_metrics[metric_groups_key].each do |metric_key, metric_value|
          metric_value.each do |metric_hash_key, metric_hash_value|
            output([config[:scheme], metric_groups_key, metric_key, metric_hash_key].join('.'), metric_hash_value) \
              if metric_hash_value.is_a?(Numeric) && (metric_hash_key == 'count' || metric_hash_key == 'value')
          end
        end
      end
      ok
    rescue Errno::ECONNREFUSED
      critical 'Jenkins is not responding'
    rescue RestClient::RequestTimeout
      critical 'Jenkins Connection timed out'
    end
    ok
  end
end
