#! /usr/bin/env ruby
#
# billing_metrics
#
# DESCRIPTION:
#   Get AWS billing metrics
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#   Returns the metrics "EstimatedCharges"(estimated charges for your AWS usage).
#   For more information see http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/billing-metricscollected.html
#
# LICENSE:
#   Jun Ichikawa <jun1ka0@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'aws-sdk-v1'

class BillingMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: ''

  option :metrics,
         description: 'Metric name.',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: ''

  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY']

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as eu-west-1).',
         default: 'us-east-1'

  def aws_config
    hash = {}
    hash.update aws_access_key_id: config[:aws_access_key], aws_secret_access_key: config[:aws_secret_access_key]\
      if config[:aws_access_key] && config[:aws_secret_access_key]
    hash.update region: config[:aws_region]
    hash
  end

  def run
    if config[:scheme] == ''
      graphitepath = "billing"
    else
      graphitepath = config[:scheme]
    end
    begin
      AWS.config(aws_config)
      metric = AWS::CloudWatch::Metric.new(
        'AWS/Billing',
        'EstimatedCharges',
        :dimensions => [
          {:name => 'Currency', :value => 'USD'}
        ]
      )
      stats = metric.statistics(
        :start_time => Time.now - 15000,
        :end_time => Time.now,
        :statistics => ['Maximum'])

      bill = 0
      stats.each do |datapoint|
        bill = datapoint[:maximum]
      end
      output graphitepath, bill
    rescue => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end

end