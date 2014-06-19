#!/usr/bin/env ruby
#
# Check DynamoDB
# ==============
#
# Check DynamoDB statuses by CloudWatch and DynamoDB API.
#
# Examples
# --------------
#
#     # Warning if any table's consumed read/write capacity is over 80%, critical if over 90%
#     check-dynamodb-capacity --warning-over 80 --critical-over 90
#
#     # Critical if session table's consumed read capacity is over 90%, maximum of last one hour
#     check-dynamodb-capacity --table_names session --capacity-for read --critical-over 90 --statistics maximum --period 3600
#
# Copyright 2014 github.com/y13i
#

require "sensu-plugin/check/cli"
require "aws-sdk"

class CheckDynamoDB < Sensu::Plugin::Check::CLI
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

  option :table_names,
    short:       "-t N",
    long:        "--table-names NAMES",
    proc:        proc {|a| a.split(/[,;]\s*/)},
    description: "Table names to check. Separated by , or ;. If not specified, check all tables"

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

  option :capacity_for,
    short:       "-c N",
    long:        "--capacity-for NAME",
    default:     [:read, :write],
    proc:        proc {|a| a.split(/[,;]\s*/).map {|n| n.downcase.intern}},
    description: "Read/Write (or both) capacity to check."

  %w(warning critical).each do |severity|
    option :"#{severity}_over",
      long:        "--#{severity}-over N",
      proc:        proc {|a| a.to_f},
      description: "Trigger a #{severity} if consumed capacity is over a percentage"
  end

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] && config[:secret_access_key]
    hash.update region: config[:region] if config[:region]
    hash
  end

  def dynamo_db
    @dynamo_db ||= AWS::DynamoDB.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= AWS::CloudWatch.new aws_config
  end

  def tables
    return @tables if @tables
    @tables = dynamo_db.tables.to_a
    @tables.select! {|table| config[:table_names].include? table.name} if config[:table_names]
    @tables
  end

  def cloud_watch_metric(metric_name, table_name)
    cloud_watch.metrics.with_namespace("AWS/DynamoDB").with_metric_name(metric_name).with_dimensions(name: "TableName", value: table_name).first
  end

  def statistics_options
    {
      start_time: config[:end_time] - config[:period],
      end_time:   config[:end_time],
      statistics: [config[:statistics].to_s.capitalize],
      period:     config[:period],
    }
  end

  def latest_value(metric)
    metric.statistics(statistics_options.merge unit: "Count").datapoints.sort_by {|datapoint| datapoint[:timestamp]}.last[config[:statistics]]
  end

  def flag_alert(severity, message)
    @severities[severity] = true
    @message += message
  end

  def check_capacity(table)
    config[:capacity_for].each do |r_or_w|
      metric_name   = "Consumed#{r_or_w.to_s.capitalize}CapacityUnits"
      metric        = cloud_watch_metric metric_name, table.name
      metric_value  = begin
                        latest_value(metric)
                      rescue
                        0
                      end
      percentage    = metric_value / table.send("#{r_or_w}_capacity_units").to_f * 100

      @severities.keys.each do |severity|
        threshold = config[:"#{severity}_over"]
        next unless threshold
        next if percentage < threshold
        flag_alert severity, "; Consumed #{r_or_w} capacity is #{sprintf "%.2f", percentage}% (expected_lower_than #{threshold})"
        break
      end
    end
  end

  def run
    @message    = "#{tables.size} tables total"
    @severities = {
                    critical: false,
                    warning: false,
                  }

    tables.each {|table| check_capacity table}

    @message += "; (#{config[:statistics].to_s.capitalize} within #{config[:period]} seconds "
    @message += "between #{config[:end_time] - config[:period]} to #{config[:end_time]})"

    if @severities[:critical]
      critical @message
    elsif @severities[:warning]
      warning @message
    else
      ok @message
    end
  end
end
