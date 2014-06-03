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
#     # critical if DB instance "sensu-admin-db" is not on ap-northeast-1a
#     check-procs -i sensu-admin-db --availability-zone-critical ap-northeast-1a
#
# Copyright 2014 github.com/y13i
#

require "sensu-plugin/check/cli"
require "aws-sdk"

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

  option :availability_zone_warning,
    long:        "--availability-zone-warning AZ",
    description: "Trigger a warning if availability zone is different than given argument"

  option :availability_zone_critical,
    long:        "--availability-zone-critical AZ",
    description: "Trigger a critical if availability zone is different than given argument"

  option :cpu_warning_over,
    long:        "--cpu-warning-over N",
    description: "Trigger a warning if CPUUtilization is over a percentage",
    proc:        proc {|a| a.to_i}

  option :cpu_critical_over,
    long:        "--cpu-critical-over N",
    description: "Trigger a critical if CPUUtilization is over a percentage",
    proc:        proc {|a| a.to_i}

  option :memory_warning_over,
    long:        "--memory-warning-over N",
    description: "Trigger a warning if memory usage is over a percentage",
    proc:        proc {|a| a.to_i}

  option :memory_critical_over,
    long:        "--memory-critical-over N",
    description: "Trigger a critical if memory usage is over a percentage",
    proc:        proc {|a| a.to_i}

  option :disk_warning_over,
    long:        "--disk-warning-over N",
    description: "Trigger a warning if disk usage is over a percentage",
    proc:        proc {|a| a.to_i}

  option :disk_critical_over,
    long:        "--disk-critical-over N",
    description: "Trigger a critical if disk usage is over a percentage",
    proc:        proc {|a| a.to_i}

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] and config[:secret_access_key]
    hash.update region: config[:region] if config[:region]
    hash
  end

  def rds
    @rds ||= AWS::RDS.new aws_config
  end

  def cloud_watch
    @cloud_watch ||= AWS::ClouWatch.new aws_config
  end

  def run
    begin
      fail if !config[:db_instance_id] or config[:db_instance_id].empty?
      db = rds.instances[config[:db_instance_id]]
      fail unless db.exists?
    rescue
      unknown "DB instance not found."
    end

    message  = "DB instance #{db.inspect}"
    az       = db.availability_zone_name
    statuses = {warning: false, critical: false}

    statuses.keys.each do |status|
      if config[:"availability_zone_#{status}"] and az != config[:"availability_zone_#{status}"]
        statuses[status] = true
        message += "; AZ is now #{az} (expected #{config[:"availability_zone_#{status}"]})"
      end

      # TODO
      # CPU, memory, disk checks!
    end

    if statuses[:critical]
      critical message
    elsif statuses[:warning]
      warning message
    else
      ok message
    end
  end
end
