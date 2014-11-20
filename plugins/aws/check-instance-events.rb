#!/usr/bin/env ruby
#
# ===
#
# DESCRIPTION:
#   This plugin looks up all instances in an account and alerts if one or more have a scheduled
#   event (reboot, retirement, etc)
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin >= 1.5 Ruby gem
#   aws-sdk Ruby gem
#
# Copyright (c) 2014, Tim Smith, tim@cozy.co
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckInstanceEvents < Sensu::Plugin::Check::CLI
  option :aws_access_key,
    :short => '-a AWS_ACCESS_KEY',
    :long => '--aws-access-key AWS_ACCESS_KEY',
    :description => "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
    :default => ENV['AWS_ACCESS_KEY_ID']

  option :use_iam_role,
    :short => '-u',
    :long => '--use-iam',
    :description => "Use IAM role authenticiation. Instance must have IAM role assigned for this to work"

  option :aws_secret_access_key,
    :short => '-s AWS_SECRET_ACCESS_KEY',
    :long => '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
    :description => "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
    :default => ENV['AWS_SECRET_ACCESS_KEY']

  option :aws_region,
    :short => '-r AWS_REGION',
    :long => '--aws-region REGION',
    :description => "AWS Region (such as eu-west-1).",
    :default => 'us-east-1'

  def run
    event_instances = []
    aws_config =   {}

    if config[:use_iam_role].nil?
      aws_config.merge!(
        :access_key_id      => config[:aws_access_key],
        :secret_access_key  => config[:aws_secret_access_key]
      )
    end

    ec2 = AWS::EC2::Client.new(aws_config.merge!(:region  => config[:aws_region]))
    begin
      ec2.describe_instance_status[:instance_status_set].each do |i|
        event_instances << i[:instance_id] unless i[:events_set].empty?
      end
    rescue Exception => e
      unknown "An error occurred processing AWS EC2 API: #{e.message}"
    end

    if event_instances.count > 0
      critical("#{event_instances.count} instances #{event_instances.count > 1 ? 'have' : 'has'} upcoming scheduled events: #{event_instances.join(',')}")
    else
      ok
    end
  end
end
