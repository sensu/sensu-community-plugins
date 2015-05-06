#! /usr/bin/env ruby
#
# rds-metrics
#
# DESCRIPTION:
#   Gets RDS metrics from CloudWatch and puts them in Graphite for longer term storage
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   rds-metrics --aws-region eu-west-1
#   rds-metrics --aws-region eu-west-1 --name sr2x8pbti0eon1
#
# NOTES:
#   Returns all RDS statistics for all RDS instances in this account unless you specify --name
#
# LICENSE:
#   Copyright 2013 Bashton Ltd http://www.bashton.com/
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'aws-sdk-v1'

class RDSMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :rdsname,
         description: 'Name of the Relational Database Service instance',
         short: '-n RDS_NAME',
         long: '--name RDS_NAME'

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
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         required: true,
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
         required: true,
         default: ENV['AWS_SECRET_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as eu-west-1).',
         default: 'us-east-1'

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] && config[:secret_access_key]
    hash.update region: config[:aws_region]
    hash
  end

  def run
    statistic_type = {
      'CPUUtilization' => 'Average',
      'DatabaseConnections' => 'Average',
      'FreeStorageSpace' => 'Average',
      'ReadIOPS' => 'Average',
      'ReadLatency' => 'Average',
      'ReadThroughput' => 'Average',
      'WriteIOPS' => 'Average',
      'WriteLatency' => 'Average',
      'WriteThroughput' => 'Average',
      'ReplicaLag' => 'Average',
      'SwapUsage' => 'Average',
      'BinLogDiskUsage' => 'Average',
      'DiskQueueDepth' => 'Average'
    }

    begin
      et = Time.now - config[:fetch_age]
      st = et - 60

      cw = AWS::CloudWatch::Client.new aws_config

      unless config[:rdsname]
        rdss = AWS::RDS.new aws_config
        config[:rdsname] = ''
        rdss.instances.each do |rds|
          config[:rdsname] += rds.db_instance_id + ' '
        end
      end

      options = {
        'namespace' => 'AWS/RDS',
        'dimensions' => [
          {
            'name' => 'DBInstanceIdentifier',
            'value' => '' # Will be filled in the each block below
          }
        ],
        'start_time' => st.iso8601,
        'end_time' => et.iso8601,
        'period' => 60
      }

      result = {}
      graphitepath = config[:scheme]

      config[:rdsname].split(' ').each do |rdsname| # rubocop:disable Next
        statistic_type.each do |key, value|
          unless config[:scheme] == ''
            graphitepath = "#{config[:scheme]}."
          end
          options['metric_name'] = key
          options['dimensions'][0]['value'] = rdsname
          options['statistics'] = [value]
          r = cw.get_metric_statistics(options)
          result[rdsname + '.' + key] = r[:datapoints][0] unless r[:datapoints][0].nil?
        end
        unless result.nil?
          # We only return data when we have some to return
          result.each do |key, value|
            output graphitepath + "#{key.downcase}", value.to_a.last[1], value[:timestamp].to_i
          end
        end
      end
    rescue => e
      critical "Error: exception: #{e}"
    end
    ok
  end
end
