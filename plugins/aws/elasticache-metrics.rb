#! /usr/bin/env ruby
#
# elasticache-metrics
#
# DESCRIPTION:
#   Fetch Elasticache metrics from CloudWatch
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# needs example command
# USAGE:
#   #YELLOW

# NOTES:
#   Redis: http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/CacheMetrics.Redis.html
#   Memcached: http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/CacheMetrics.Memcached.html
#
#   By default fetches all available statistics from one minute ago.  You may need to fetch further back than this;
#
# LICENSE:
#   Copyright 2014 Yann Verry
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'aws-sdk'

class ElastiCacheMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :cacheclusterid,
         description: 'Name of the Cache Cluster',
         short: '-n ELASTICACHE_NAME',
         long: '--name ELASTICACHE_NAME',
         required: true

  option :cachenodeid,
         description: 'Cache Node ID',
         short: '-i CACHE_NODE_ID',
         long: '--cache-node-id CACHE_NODE_ID',
         default: '0001'

  option :elasticachetype,
         description: 'Elasticache type redis or memcached',
         short: '-c TYPE',
         long: '--cachetype TYPE',
         required: true

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: ''

  option :fetch_age,
         description: 'How long ago to fetch metrics for',
         short: '-f AGE',
         long: '--fetch_age',
         default: 60,
         proc: proc(&:to_i)

  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option"

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option"

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as us-east-1).',
         default: 'us-east-1'

  def run
    if config[:scheme] == ''
      graphitepath = "#{config[:elasticachename]}.#{config[:metric].downcase}"
    else
      graphitepath = config[:scheme]
    end

    statistic_type = {
      'redis' => {
        'CPUUtilization' => 'Percent',
        'SwapUsage' => 'Bytes',
        'FreeableMemory' => 'Bytes',
        'NetworkBytesIn' => 'Bytes',
        'NetworkBytesOut' => 'Bytes',
        'GetTypeCmds' => 'Count',
        'SetTypeCmds' => 'Count',
        'KeyBasedCmds' => 'Count',
        'StringBasedCmds' => 'Count',
        'HashBasedCmds' => 'Count',
        'ListBasedCmds' => 'Count',
        'SetBasedCmds' => 'Count',
        'SortedSetBasedCmds' => 'Count',
        'CurrItems' => 'Count'
      },
      'memcached' => {
        'CPUUtilization' => 'Percent',
        'SwapUsage' => 'Bytes',
        'FreeableMemory' => 'Bytes',
        'NetworkBytesIn' => 'Bytes',
        'NetworkBytesOut' => 'Bytes',
        'BytesUsedForCacheItems' => 'Bytes',
        'BytesReadIntoMemcached' => 'Bytes',
        'BytesWrittenOutFromMemcached' => 'Bytes',
        'CasBadval' => 'Count',
        'CasHits' => 'Count',
        'CasMisses' => 'Count',
        'CmdFlush' => 'Count',
        'CmdGet' => 'Count',
        'CmdSet' => 'Count',
        'CurrConnections' => 'Count',
        'CurrItems' => 'Count',
        'DecrHits' => 'Count',
        'DecrMisses' => 'Count',
        'DeleteHits' => 'Count',
        'DeleteMisses' => 'Count',
        'Evictions' => 'Count',
        'GetHits' => 'Count',
        'GetMisses' => 'Count',
        'IncrHits' => 'Count',
        'IncrMisses' => 'Count',
        'Reclaimed' => 'Count',
        'BytesUsedForHash' => 'Bytes',
        'CmdConfigGet' => 'Count',
        'CmdConfigSet' => 'Count',
        'CmdTouch' => 'Count',
        'CurrConfig' => 'Count',
        'EvictedUnfetched' => 'Count',
        'ExpiredUnfetched' => 'Count',
        'SlabsMoved' => 'Count',
        'TouchHits' => 'Count',
        'TouchMisses' => 'Count',
        'NewConnections' => 'Count',
        'NewItems' => 'Count',
        'UnusedMemory' => 'Bytes'
      }
    }

    begin

      AWS.config(
        access_key_id: config[:aws_access_key],
        secret_access_key: config[:aws_secret_access_key],
        region: config[:aws_region]
      )

      et = Time.now - config[:fetch_age]
      st = et - 60

      cw = AWS::CloudWatch::Client.new

      # define all options
      options = {
        'namespace' => 'AWS/ElastiCache',
        'metric_name' => config[:metric],
        'dimensions' => [
          { 'name' => 'CacheClusterId', 'value' => config[:cacheclusterid] }
        ],
        'start_time' => st.iso8601,
        'end_time' => et.iso8601,
        'period' => 60,
        'statistics' => ['Average']
      }

      result = {}

      # Fetch all metrics by elasticachetype (redis or memcached).
      statistic_type[config[:elasticachetype]].each do |m|
        options['metric_name'] = m[0] # override metric
        r = cw.get_metric_statistics(options)
        result[m[0]] = r[:datapoints][0] unless r[:datapoints][0].nil?
      end

      unless result.nil?
        result.each do |name, d|
          # We only return data when we have some to return
          output graphitepath + '.' + name.downcase, d[:average], d[:timestamp].to_i
        end
      end
    rescue => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
