#!/usr/bin/env ruby
#
# Check ELB Latency
# =================
#
# Check ELB Latency by CloudWatch API.
#
# Examples
# -----------------
#
#     # Warning if any load balancer's latency is over 1 second, critical if over 3 seconds.
#     check-elb-latency --warning-over 1 --critical-over 3
#
#     # Critical if "app" load balancer's latency is over 5 seconds, maximum of last one hour
#     check-elb-latency --elb-names app --critical-over 5 --statistics maximum --period 3600
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

  option :statistics,
    short:       "-S N",
    long:        "--statistics NAME",
    default:     :average,
    proc:        proc {|a| a.downcase.intern},
    description: "CloudWatch statistics method"

  %w(warning critical).each do |severity|
    option :"#{severity}_over",
      long:        "--#{severity}-over SECONDS",
      proc:        proc {|a| a.to_f},
      description: "Trigger a #{severity} if latancy is over specified seconds"
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
    cloud_watch.metrics.with_namespace("AWS/ELB").with_metric_name("Latency").with_dimensions(name: "LoadBalancerName", value: elb_name).first
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
    metric.statistics(statistics_options.merge unit: "Seconds").datapoints.sort_by {|datapoint| datapoint[:timestamp]}.last[config[:statistics]]
  end

  def flag_alert(severity, message)
    @severities[severity] = true
    @message += message
  end

  def check_latency(elb)
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
        "; #{elbs.size == 1 ? nil : "#{elb.inspect}'s"} Latency is #{sprintf "%.3f", metric_value} seconds. (expected lower than #{sprintf "%.3f", threshold})"
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

    elbs.each {|elb| check_latency elb}

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
