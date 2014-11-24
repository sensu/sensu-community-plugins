#!/usr/bin/env ruby
#
# Check ELB Sum Requests
# ======================
#
# Check ELB Sum Requests by CloudWatch API.
#
# Examples
# ----------------------
#
#     # Warning if any load balancer's sum request count is over 1000, critical if over 2000.
#     check-elb-sum-requests --warning-over 1000 --critical-over 2000
#
#     # Critical if "app" load balancer's sum request count is over 10000, within last one hour
#     check-elb-sum-requests --elb-names app --critical-over 10000 --period 3600
#
# Copyright 2014 github.com/y13i
#

require "sensu-plugin/check/cli"
require "aws-sdk"

class CheckELBLatency < Sensu::Plugin::Check::CLI
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

  option :elb_names,
    short:       "-l N",
    long:        "--elb-names NAMES",
    proc:        proc {|a| a.split(/[,;]\s*/)},
    description: "Load balancer names to check. Separated by , or ;. If not specified, check all load balancers"

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

  %w(warning critical).each do |severity|
    option :"#{severity}_over",
      long:        "--#{severity}-over COUNT",
      proc:        proc {|a| a.to_f},
      description: "Trigger a #{severity} if sum requests is over specified count"
  end

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] && config[:secret_access_key]
    hash.update region: config[:region] if config[:region]
    hash
  end

  def elb
    @elb ||= AWS::ELB.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= AWS::CloudWatch.new aws_config
  end

  def elbs
    return @elbs if @elbs
    @elbs = elb.load_balancers.to_a
    @elbs.select! {|elb| config[:elb_names].include? elb.name} if config[:elb_names]
    @elbs
  end

  def latency_metric(elb_name)
    cloud_watch.metrics.with_namespace("AWS/ELB").with_metric_name("RequestCount").with_dimensions(name: "LoadBalancerName", value: elb_name).first
  end

  def statistics_options
    {
      start_time: config[:end_time] - config[:period],
      end_time:   config[:end_time],
      statistics: ["Sum"],
      period:     config[:period],
    }
  end

  def latest_value(metric)
    metric.statistics(statistics_options.merge unit: "Count").datapoints.sort_by {|datapoint| datapoint[:timestamp]}.last[:sum]
  end

  def flag_alert(severity, message)
    @severities[severity] = true
    @message += message
  end

  def check_sum_requests(elb)
    metric        = latency_metric elb.name
    metric_value  = begin
                      latest_value metric
                    rescue
                      0
                    end

    @severities.keys.each do |severity|
      threshold = config[:"#{severity}_over"]
      next unless threshold
      next if metric_value < threshold
      flag_alert severity,
        "; #{elbs.size == 1 ? nil : "#{elb.inspect}'s"} Sum Requests is #{metric_value}. (expected lower than #{threshold})"
      break
    end
  end

  def run
    @message  = if elbs.size == 1
                  elbs.first.inspect
                else
                  "#{elbs.size} load balancers total"
                end

    @severities = {
                    critical: false,
                    warning:  false,
                  }

    elbs.each {|elb| check_sum_requests elb}

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
