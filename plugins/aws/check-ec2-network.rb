#! /usr/bin/env ruby
#
# check-ec2-network
#
# DESCRIPTION:
#   Check EC2 Network Metrics by CloudWatch API.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   ./check-ec2-network.rb -r ${you_region} -i ${your_instance_id} --warning-over 1000000 --critical-over 1500000
#   ./check-ec2-network.rb -r ${you_region} -i ${your_instance_id} -d NetworkIn --warning-over 1000000 --critical-over 1500000
#   ./check-ec2-network.rb -r ${you_region} -i ${your_instance_id} -d NetworkOut --warning-over 1000000 --critical-over 1500000
#
# NOTES:
#
# LICENSE:
#   Yohei Kawahara <inokara@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckEc2Network < Sensu::Plugin::Check::CLI
  option :access_key_id,
         short:       '-k N',
         long:        '--access-key-id ID',
         description: 'AWS access key ID'

  option :secret_access_key,
         short:       '-s N',
         long:        '--secret-access-key KEY',
         description: 'AWS secret access key'

  option :region,
         short:       '-r R',
         long:        '--region REGION',
         description: 'AWS region'

  option :instance_id,
         short:       '-i instance-id',
         long:        '--instance-id instance-ids',
         description: 'EC2 Instance ID to check.'

  option :end_time,
         short:       '-t T',
         long:        '--end-time TIME',
         default:     Time.now,
         description: 'CloudWatch metric statistics end time'

  option :period,
         short:       '-p N',
         long:        '--period SECONDS',
         default:     60,
         description: 'CloudWatch metric statistics period'

  option :direction,
         short:       '-d NetworkIn or NetworkOut',
         long:        '--direction NetworkIn or NetworkOut',
         default:     'NetworkIn',
         description: 'Select NetworkIn or NetworkOut'

  %w(warning critical).each do |severity|
    option :"#{severity}_over",
           long:        "--#{severity}-over COUNT",
           description: "Trigger a #{severity} if network traffice is over specified Bytes"
  end

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] && config[:secret_access_key]
    hash.update region: config[:region] if config[:region]
    hash
  end

  def ec2
    @ec2 ||= AWS::EC2.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= AWS::CloudWatch.new aws_config
  end

  def network_metric(instance)
    cloud_watch.metrics.with_namespace('AWS/EC2').with_metric_name("#{config[:direction]}").with_dimensions(name: 'InstanceId', value: instance).first
  end

  def statistics_options
    {
      start_time: config[:end_time] - 300,
      end_time:   config[:end_time],
      statistics: ['Average'],
      period:     config[:period]
    }
  end

  def latest_value(metric)
    value = metric.statistics(statistics_options.merge unit: 'Bytes')
    # #YELLOW
    unless value.datapoints[0].nil? # rubocop:disable IfUnlessModifier, GuardClause
      value.datapoints[0][:average].to_f
    end
  end

  def check_metric(instance)
    metric = network_metric instance
    latest_value metric
  end

  def run
    metric_value = check_metric config[:instance_id]
    if !metric_value.nil? && metric_value > config[:critical_over].to_f
      critical "#{config[:direction]} at #{metric_value} Bytes"
    elsif !metric_value.nil? && metric_value > config[:warning_over].to_f
      warning "#{config[:direction]} at #{metric_value} Bytes"
    else
      ok "#{config[:direction]} at #{metric_value} Bytes"
    end
  end
end
