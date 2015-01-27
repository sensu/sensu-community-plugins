#! /usr/bin/env ruby
#
# autoscaling-instance-count-metrics
#
# DESCRIPTION:
#   Get a count of instances in a given AutoScaling group
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
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2013 Bashton Ltd http://www.bashton.com/
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'aws-sdk'

class AutoScalingInstanceCountMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :groupname,
         description: 'Name of the AutoScaling group',
         short: '-g GROUP_NAME',
         long: '--autoscaling-group GROUP_NAME',
         required: true

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
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
      graphitepath = "#{config[:groupname]}.autoscaling.instance_count"
    else
      graphitepath = config[:scheme]
    end
    begin
      as = AWS::AutoScaling.new aws_config
      count = as.groups[config[:groupname]].auto_scaling_instances.map { |i| i.lifecycle_state }.count('InService')
      output graphitepath, count
    rescue => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
