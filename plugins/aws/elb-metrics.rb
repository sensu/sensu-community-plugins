#! /usr/bin/env ruby
#
# elb-latency-metrics
#
# DESCRIPTION:
#   Gets latency metrics from CloudWatch and puts them in Graphite for longer term storage
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
#   #YELLOW
#
# NOTES:
#   Returns latency statistics by default.  You can specify any valid ELB metric type, see
#   http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/CW_Support_For_AWS.html#elb-metricscollected
#
#   By default fetches statistics from one minute ago.  You may need to fetch further back than this;
#   high traffic ELBs can sometimes experience statistic delays of up to 10 minutes.  If you experience this,
#   raising a ticket with AWS support should get the problem resolved.
#   As a workaround you can use eg -f 300 to fetch data from 5 minutes ago.
#
# LICENSE:
#   Copyright 2013 Bashton Ltd http://www.bashton.com/
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'aws-sdk-v1'

class ELBMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :elbname,
         description: 'Name of the Elastic Load Balancer',
         short: '-n ELB_NAME',
         long: '--name ELB_NAME'

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

  option :metric,
         description: 'Metric to fetch',
         short: '-m METRIC',
         long: '--metric',
         default: 'Latency'

  option :statistic,
         rescription: 'Statistics type',
         short: '-t STATISTIC',
         long: '--statistic',
         default: ''

  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_KEY',
         long: '--aws-secret-access-key AWS_SECRET_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_KEY'] or provide it as an option",
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
    statistic = ''
    if config[:statistic] == ''
      default_statistic_per_metric = {
        'Latency' => 'Average',
        'RequestCount' => 'Sum',
        'UnHealthyHostCount' => 'Average',
        'HealthyHostCount' => 'Average',
        'HTTPCode_Backend_2XX' => 'Sum',
        'HTTPCode_Backend_4XX' => 'Sum',
        'HTTPCode_Backend_5XX' => 'Sum',
        'HTTPCode_ELB_4XX' => 'Sum',
        'HTTPCode_ELB_5XX' => 'Sum',
        'BackendConnectionErrors' => 'Sum',
        'SurgeQueueLength' => 'Max',
        'SpilloverCount' => 'Sum'
      }
      statistic = default_statistic_per_metric[config[:metric]]
    else
      statistic = config[:statistic]
    end

    begin
      et = Time.now - config[:fetch_age]
      st = et - 60

      cw = AWS::CloudWatch::Client.new aws_config

      options = {
        'namespace' => 'AWS/ELB',
        'metric_name' => config[:metric],
        'dimensions' => [
          {
            'name' => 'LoadBalancerName',
            'value' => config[:elbname]
          }
        ],
        'statistics' => [statistic],
        'start_time' => st.iso8601,
        'end_time' => et.iso8601,
        'period' => 60
      }
      result = cw.get_metric_statistics(options)
      data = result[:datapoints][0]
      unless data.nil?
        # We only return data when we have some to return
        graphitepath = config[:scheme]
        if config[:scheme] == ''
          graphitepath = "#{config[:elbname]}.#{config[:metric].downcase}"
        end
        output graphitepath, data[statistic.downcase.to_sym], data[:timestamp].to_i
      end
    rescue => e
      critical "Error: exception: #{e}"
    end
    ok
  end
end
