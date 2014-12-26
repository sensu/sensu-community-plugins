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
#   gem: fog
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
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
require 'fog'

class AutoScalingInstanceCountMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :groupname,
         description: 'Name of the AutoScaling group',
         short: '-g GROUP_NAME',
         long: '--autoscaling-group GROUP_NAME'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: ''

  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
         required: true

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
         required: true

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as eu-west-1).',
         default: 'us-east-1'

  def run
    if config[:scheme] == ''
      graphitepath = "#{config[:groupname]}.autoscaling.instance_count"
    else
      graphitepath = config[:scheme]
    end
    begin
      as = Fog::AWS::AutoScaling.new(
        aws_access_key_id: config[:aws_access_key],
        aws_secret_access_key: config[:aws_secret_access_key],
        region: config[:aws_region])
      count = as.groups.get(config[:groupname]).instances.map(&:life_cycle_state).count('InService')
      output graphitepath, count

    rescue => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
