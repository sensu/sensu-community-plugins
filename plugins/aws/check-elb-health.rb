#!/usr/bin/env ruby
#
# Checks an ELB's health
# ===
#
# DESCRIPTION:
#   This plugin checks the health of an Amazon Elastic Load Balancer.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   right_aws Ruby gem
#
# Copyright (c) 2012, Panagiotis Papadomitsos <pj@ezgr.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'uri'
require 'right_aws'

class ELBHealth < Sensu::Plugin::Check::CLI

  option :aws_access_key,
    :short => '-a AWS_ACCESS_KEY',
    :long => '--aws-access-key AWS_ACCESS_KEY',
    :description => "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
    :required => true,
    :default => ENV['AWS_ACCESS_KEY_ID']

  option :aws_secret_access_key,
    :short => '-s AWS_SECRET_ACCESS_KEY',
    :long => '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
    :description => "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
    :required => true,
    :default => ENV['AWS_SECRET_ACCESS_KEY']

  option :aws_region,
    :short => '-r AWS_REGION',
    :long => '--aws-region REGION',
    :description => "AWS Region (such as eu-west-1). If you do not specify a region, it will be detected by the server the script is run on"

  option :elb_name,
    :short => '-n ELB_NAME',
    :long => '--elb-name ELB_NAME',
    :description => 'The Elastic Load Balancer name of which you want to check the health',
    :required => true

  option :instances,
    :short => '-i INSTANCES',
    :long => '--instances INSTANCES',
    :description => 'Comma separated list of specific instances IDs inside the ELB of which you want to check the health'

  option :verbose,
    :short => '-v',
    :long => '--verbose',
    :description => 'Enable a little bit more verbose reports about instance health',
    :boolean => true,
    :default => false

  def query_instance_region
    begin
      instance_az = nil
      Timeout.timeout(3) do
        instance_az = Net::HTTP.get(URI('http://169.254.169.254/latest/meta-data/placement/availability-zone/'))
      end
      instance_az[0...-1]
    rescue Exception
      raise "Cannot obtain this instance's Availability Zone. Maybe not running on AWS?"
    end
  end

  def run
    begin
      aws_region = (config[:aws_region].nil? || config[:aws_region].empty?) ? query_instance_region : config[:aws_region]
      elb = RightAws::ElbInterface.new(config[:aws_access_key], config[:aws_secret_access_key], {
        :logger => Logger.new('/dev/null'),
        :cache => false,
        :server => "elasticloadbalancing.#{aws_region}.amazonaws.com"
      })
      if config[:instances]
        instances = config[:instances].split(',')
        health = elb.describe_instance_health(config[:elb_name], instances)
      else
        health = elb.describe_instance_health(config[:elb_name])
      end
    rescue Exception => e
      critical "An issue occured while communicating with the AWS EC2 API: #{e.message}"
    end
    unless health.empty?
      unhealthy_instances = {}
      health.each do |instance|
        unhealthy_instances[instance[:instance_id]] = instance[:state] unless instance[:state].eql?('InService')
      end
      unless unhealthy_instances.empty?
        if config[:verbose]
          critical "Unhealthy instances detected: #{unhealthy_instances.map{|id, state| '[' + id + '::' + state + ']' }.join(' ')}"
        else
          critical "Detected [#{unhealthy_instances.size}] unhealthy instances"
        end
      else
        ok "All instances on ELB #{aws_region}::#{config[:elb_name]} healthy!"
      end
    else
      critical 'Failed to retrieve ELB instance health data'
    end
  end

end
