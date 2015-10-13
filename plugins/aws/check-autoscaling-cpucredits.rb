#! /usr/bin/env ruby
#
# check-autoscaling-cpucredits
#
# DESCRIPTION:
#   Check AutoScaling CPU Credits through CloudWatch API.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#   ./check-autoscaling-cpucredits.rb -r ${your_region} --warning-under 100 --critical-under 50
#
# NOTES:
#   Based heavily on Yohei Kawahara's check-ec2-network
#
# LICENSE:
#   Gavin Hamill <gavin@bashton.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'aws-sdk-v1'

class CheckEc2CpuCredits < Sensu::Plugin::Check::CLI
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

  option :group,
         short:       '-g G',
         long:        '--autoscaling-group GROUP',
         description: 'AutoScaling group to check'

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

  option :countmetric,
         short:       '-d M',
         long:        '--countmetric METRIC',
         default:     'CPUCreditBalance',
         description: 'Select any CloudWatch _Count_ based metric (Status Checks / CPU Credits)'

  option :warning_under,
         short:       '-w N',
         long:        '--warning-under VALUE',
         description: 'Issue a warning if the CloudWatch _Count_ based metric (Status Check / CPU Credits) is below this value'

  option :critical_under,
         short:       '-c N',
         long:        '--critical-under VALUE',
         description: 'Issue a critical if the CloudWatch _Count_ based metric (Status Check / CPU Credits) is below this value'

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] && config[:secret_access_key]
    hash.update region: config[:region] if config[:region]
    hash
  end

  def asg
    @asg ||= AWS::AutoScaling.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= AWS::CloudWatch.new aws_config
  end

  def get_count_metric(group)
    cloud_watch.metrics
      .with_namespace('AWS/EC2')
      .with_metric_name("#{config[:countmetric]}")
      .with_dimensions(name: 'AutoScalingGroupName', value: group)
      .first
  end

  def statistics_options
    {
      start_time: config[:end_time] - 600,
      end_time:   config[:end_time],
      statistics: ['Average'],
      period:     config[:period]
    }
  end

  def latest_value(metric)
    value = metric.statistics(statistics_options.merge unit: 'Count')
    # #YELLOW
    unless value.datapoints[0].nil? # rubocop:disable IfUnlessModifier, GuardClause
      value.datapoints[0][:average].to_f
    end
  end

  def check_metric(group)
    metric = get_count_metric group
    latest_value metric
  end

  def check_group(group, reportstring, warnflag, critflag)
    metric_value = check_metric group
    if !metric_value.nil? && metric_value < config[:critical_under].to_f
      critflag = 1
      reportstring = reportstring + group + ': ' + metric_value.to_s + ' '
    elsif !metric_value.nil? && metric_value < config[:warning_under].to_f
      warnflag = 1
      reportstring = reportstring + group + ': ' + metric_value.to_s + ' '
    end
    [reportstring, warnflag, critflag]
  end

  def run
    warnflag = 0
    critflag = 0
    reportstring = ''
    if config[:group].nil?
      asg.groups.each do |group|
        reportstring, warnflag, critflag = check_group(group.name, reportstring, warnflag, critflag)
      end
    else
      reportstring, warnflag, critflag = check_group(config[:group], reportstring, warnflag, critflag)
    end

    if critflag == 1
      critical reportstring
    elsif warnflag == 1
      warning reportstring
    else
      ok 'All checked AutoScaling Groups are cool'
    end
  end
end
