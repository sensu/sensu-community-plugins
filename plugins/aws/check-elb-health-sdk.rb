#!/usr/bin/env ruby
#
# Checks an ELB's health
# Last Update: 11/19/2014 by bkett
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
#   fog Ruby gem
#
# Copyright (c) 2014, Panagiotis Papadomitsos <pj@ezgr.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'uri'
require 'aws-sdk'

class ELBHealth < Sensu::Plugin::Check::CLI

  option :aws_access_key,
    :short => '-a AWS_ACCESS_KEY',
    :long => '--aws-access-key AWS_ACCESS_KEY',
    :description => "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
    :default => ENV['AWS_ACCESS_KEY_ID']

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

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] && config[:secret_access_key]
    hash.update region: config[:aws_region] 
    hash
  end

  def run

    unhealthy_instances = {}
    begin
      elb = AWS::ELB.new aws_config
      if config[:instances]
        instance_health_hash = elb.load_balancers[config[:elb_name]].instances.health(config[:instances])
      else
        instance_health_hash= elb.load_balancers[config[:elb_name]].instances.health
      end
      instance_health_hash.each do |instance_health|
          if instance_health[:state] != "InService"
            unhealthy_instances[instance_health[:instance].id] = instance_health[:state]
          end
      end
      unless unhealthy_instances.empty?
        if config[:verbose]
          critical "Unhealthy instances detected: #{unhealthy_instances.map{|id, state| '[' + id + '::' + state + ']' }.join(' ')}"
        else
          critical "Detected [#{unhealthy_instances.size}] unhealthy instances"
        end
      else
        ok "All instances on ELB #{config[:aws_region]}::#{config[:elb_name]} healthy!"
      end
    rescue AWS::Errors::ServerError => e
      warning "A Server-Side issue occured while communicating with the AWS API: #{e.message}"
    rescue AWS::Errors::ClientError => e
      warning "A Client-Side issue occured while communicating with the AWS API: #{e.message}"
    end
  end

end
