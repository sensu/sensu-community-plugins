#!/usr/bin/env ruby
#
# Check RDS
# ===========
#
# Check RDS instance statuses by RDS and CloudWatch API.
#
# Examples
# -----------
#
#     # Critical if DB instance "sensu-admin-db" is not on ap-northeast-1a
#     check-rds -i sensu-admin-db --availability-zone-critical ap-northeast-1a
#
#     # Warning if CPUUtilization is over 80%, critical if over 90%
#     check-rds -i sensu-admin-db --cpu-warning-over 80 --cpu-critical-over 90
#
#     # Critical if CPUUtilization is over 90%, maximum of last one hour
#     check-rds -i sensu-admin-db --cpu-critical-over 90 --statistics maximum --period 3600
#
#     # Warning if memory usage is over 80%, maximum of last 2 hour
#     # specifying "minimum" is intended actually since memory usage is calculated from CloudWatch "FreeableMemory" metric.
#     check-rds -i sensu-admin-db --memory-warning-over 80 --statistics minimum --period 7200
#
#     # Disk usage, same as memory
#     check-rds -i sensu-admin-db --disk-warning-over 80 --period 7200
#
#     # You can check multiple metrics simultaneously. Highest severity will be reported
#     check-rds -i sensu-admin-db --cpu-warning-over 80 --cpu-critical-over 90 --memory-warning-over 60 --memory-critical-over 80
#
# Copyright 2014 github.com/y13i
#

require "sensu-plugin/check/cli"
require "aws-sdk"
require "time"

class CheckRDS < Sensu::Plugin::Check::CLI
  option :access_key_id,
    short:       "-k N",
    long:        "--access-key-id ID",
    description: "AWS access key ID"

  option :secret_access_key,
    short:       "-s N",
    long:        "--secret-access-key KEY",
    description: "AWS secret access key"

  option :region,
    short:       "-r R",
    long:        "--region REGION",
    description: "AWS region"

  option :db_instance_id,
    short:       "-i N",
    long:        "--db-instance-id NAME",
    description: "DB instance identifier"

  option :end_time,
    short:       "-t T",
    long:        "--end-time TIME",
    default:     Time.now,
    proc:        proc {|a| Time.parse a},
    description: "CloudWatch metric statistics end time"

  option :period,
    short:       "-p N",
    long:        "--period SECONDS",
    default:     60,
    proc:        proc {|a| a.to_i},
    description: "CloudWatch metric statistics period"

  option :statistics,
    short:       "-S N",
    long:        "--statistics NAME",
    default:     :average,
    proc:        proc {|a| a.downcase.intern},
    description: "CloudWatch statistics method"

  %w(warning critical).each do |severity|
    option :"availability_zone_#{severity}",
      long:        "--availability-zone-#{severity} AZ",
      description: "Trigger a #{severity} if availability zone is different than given argument"

    %w(cpu memory disk).each do |item|
      option :"#{item}_#{severity}_over",
        long:        "--#{item}-#{severity}-over N",
        proc:        proc {|a| a.to_f},
        description: "Trigger a #{severity} if #{item} usage is over a percentage"
    end
  end

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] && config[:secret_access_key]
    hash.update region: config[:region] if config[:region]
    hash
  end

  def rds
    @rds ||= AWS::RDS.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= AWS::CloudWatch.new aws_config
  end

  def find_db_instance(id)
    fail if !id || id.empty?
    db = rds.instances[id]
    fail unless db.exists?
    db
  rescue
    unknown "DB instance not found."
  end

  def cloud_watch_metric(metric_name)
    cloud_watch.metrics.with_namespace("AWS/RDS").with_metric_name(metric_name).with_dimensions(name: "DBInstanceIdentifier", value: @db_instance.id).first
  end

  def statistics_options
    {
      start_time: config[:end_time] - config[:period],
      end_time:   config[:end_time],
      statistics: [config[:statistics].to_s.capitalize],
      period:     config[:period],
    }
  end

  def latest_value(metric, unit)
    metric.statistics(statistics_options.merge unit: unit).datapoints.sort_by {|datapoint| datapoint[:timestamp]}.last[config[:statistics]]
  end

  def flag_alert(severity, message)
    @severities[severity] = true
    @message += message
  end

  def memory_total_bytes(instance_class)
    memory_total_gigabytes = {
      "db.t1.micro"    => 0.615,
      "db.m1.small"    => 1.7,
      "db.m3.medium"   => 3.75,
      "db.m3.large"    => 7.5,
      "db.m3.xlarge"   => 15.0,
      "db.m3.2xlarge"  => 30.0,
      "db.r3.large"    => 15.0,
      "db.r3.xlarge"   => 30.5,
      "db.r3.2xlarge"  => 61.0,
      "db.r3.4xlarge"  => 122.0,
      "db.r3.8xlarge"  => 244.0,
      "db.m2.xlarge"   => 17.1,
      "db.m2.2xlarge"  => 34.2,
      "db.m2.4xlarge"  => 68.4,
      "db.cr1.8xlarge" => 244.0,
      "db.m1.medium"   => 3.75,
      "db.m1.large"    => 7.5,
      "db.m1.xlarge"   => 15.0,
    }

    memory_total_gigabytes.fetch(instance_class) * 1024 ** 3
  end

  def check_az(severity, expected_az)
    return if @db_instance.availability_zone_name == expected_az
    flag_alert severity, "; AZ is #{@db_instance.availability_zone_name} (expected #{expected_az})"
  end

  def check_cpu(severity, expected_lower_than)
    @cpu_metric       ||= cloud_watch_metric "CPUUtilization"
    @cpu_metric_value ||= latest_value @cpu_metric, "Percent"
    return if @cpu_metric_value < expected_lower_than
    flag_alert severity, "; CPUUtilization is #{sprintf "%.2f", @cpu_metric_value}% (expected lower than #{expected_lower_than}%)"
  end

  def check_memory(severity, expected_lower_than)
    @memory_metric           ||= cloud_watch_metric "FreeableMemory"
    @memory_metric_value     ||= latest_value @memory_metric, "Bytes"
    @memory_total_bytes      ||= memory_total_bytes @db_instance.db_instance_class
    @memory_usage_bytes      ||= @memory_total_bytes - @memory_metric_value
    @memory_usage_percentage ||= @memory_usage_bytes / @memory_total_bytes * 100
    return if @memory_usage_percentage < expected_lower_than
    flag_alert severity, "; Memory usage is #{sprintf "%.2f", @memory_usage_percentage}% (expected lower than #{expected_lower_than}%)"
  end

  def check_disk(severity, expected_lower_than)
    @disk_metric           ||= cloud_watch_metric "FreeStorageSpace"
    @disk_metric_value     ||= latest_value @disk_metric, "Bytes"
    @disk_total_bytes      ||= @db_instance.allocated_storage * 1024 ** 3
    @disk_usage_bytes      ||= @disk_total_bytes - @disk_metric_value
    @disk_usage_percentage ||= @disk_usage_bytes / @disk_total_bytes * 100
    return if @disk_usage_percentage < expected_lower_than
    flag_alert severity, "; Disk usage is #{sprintf "%.2f", @disk_usage_percentage}% (expected lower than #{expected_lower_than}%)"
  end

  def run
    @db_instance  = find_db_instance config[:db_instance_id]
    @message      = @db_instance.inspect
    @severities   = {
                      critical: false,
                      warning:  false,
                    }

    @severities.keys.each do |severity|
      check_az severity, config[:"availability_zone_#{severity}"] if config[:"availability_zone_#{severity}"]

      %w(cpu memory disk).each do |item|
        send "check_#{item}", severity, config[:"#{item}_#{severity}_over"] if config[:"#{item}_#{severity}_over"]
      end
    end

    if %w(cpu memory disk).any? {|item| %W(warning critical).any? {|severity| config[:"#{item}_#{severity}_over"]}}
      @message += "; (#{config[:statistics].to_s.capitalize} within #{config[:period]} seconds "
      @message += "between #{config[:end_time] - config[:period]} to #{config[:end_time]})"
    end

    if @severities[:critical]
      critical @message
    elsif @severities[:warning]
      warning @message
    else
      ok @message
    end
  end
end
