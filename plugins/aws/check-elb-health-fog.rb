#! /usr/bin/env ruby
#
# check-elb-health-fog
#
#
# DESCRIPTION:
#   This plugin checks the health of an Amazon Elastic Load Balancer.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: fog
#   gem: sensu-plugin
#   gem: uri
#
# USAGE:
#  ./check-ec2-network.rb -r ${you_region} -i ${your_instance_id} --warning-over 1000000 --critical-over 1500000
#  ./check-ec2-network.rb -r ${you_region} -i ${your_instance_id} -d NetworkIn --warning-over 1000000 --critical-over 1500000
#  ./check-ec2-network.rb -r ${you_region} -i ${your_instance_id} -d NetworkOut --warning-over 1000000 --critical-over 1500000
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Panagiotis Papadomitsos <pj@ezgr.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'uri'
require 'fog/aws'

class ELBHealth < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
         required: true,
         default: ENV['AWS_ACCESS_KEY_ID']

  option :aws_secret_access_key,
         short: '-s AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
         required: true,
         default: ENV['AWS_SECRET_ACCESS_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as eu-west-1). If you do not specify a region, it will be detected by the server the script is run on'

  option :elb_name,
         short: '-n ELB_NAME',
         long: '--elb-name ELB_NAME',
         description: 'The Elastic Load Balancer name of which you want to check the health',
         required: true

  option :instances,
         short: '-i INSTANCES',
         long: '--instances INSTANCES',
         description: 'Comma separated list of specific instances IDs inside the ELB of which you want to check the health'

  option :verbose,
         short: '-v',
         long: '--verbose',
         description: 'Enable a little bit more verbose reports about instance health',
         boolean: true,
         default: false

  def query_instance_region
    instance_az = nil
    Timeout.timeout(3) do
      instance_az = Net::HTTP.get(URI('http://169.254.169.254/latest/meta-data/placement/availability-zone/'))
    end
    instance_az[0...-1]
  rescue
    raise "Cannot obtain this instance's Availability Zone. Maybe not running on AWS?"
  end

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] && config[:secret_access_key]
    hash.update region: config[:region]
    hash
  end

  def run
    aws_region = (config[:aws_region].nil? || config[:aws_region].empty?) ? query_instance_region : config[:aws_region]
    begin
      elb = Fog::AWS::ELB.new aws_config
      if config[:instances]
        instances = config[:instances].split(',')
        health = elb.describe_instance_health(config[:elb_name], instances)
      else
        health = elb.describe_instance_health(config[:elb_name])
      end
      unhealthy_instances = {}
      health.body['DescribeInstanceHealthResult']['InstanceStates'].each do |instance|
        unhealthy_instances[instance['InstanceId']] = instance['State'] unless instance['State'].eql?('InService')
      end
      if unhealthy_instances.empty?
        ok "All instances on ELB #{aws_region}::#{config[:elb_name]} healthy!"
      else
        if config[:verbose]
          critical "Unhealthy instances detected: #{unhealthy_instances.map { |id, state| '[' + id + '::' + state + ']' }.join(' ') }"
        else
          critical "Detected [#{unhealthy_instances.size}] unhealthy instances"
        end
      end
    rescue => e
      warning "An issue occured while communicating with the AWS EC2 API: #{e.message}"
    end
  end
end
