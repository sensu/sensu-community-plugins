#! /usr/bin/env ruby
#
# ec2-count-metrics
#
# DESCRIPTION:
#   This plugin retrives number of EC2 status
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
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Tim Smith, tim@cozy.co
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'aws-sdk-v1'

class EC2Metrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'sensu.aws.ec2'

  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option"

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option"

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as us-east-1).',
         default: 'us-east-1'

  option :type,
         short: '-t METRIC type',
         long: '--type METRIC type',
         description: 'Count by type: status, instance',
         default: 'instance'

  def aws_config
    hash = {}
    hash.update access_key_id: config[:access_key_id], secret_access_key: config[:secret_access_key] if config[:access_key_id] && config[:secret_access_key]
    hash.update region: config[:aws_region]
    hash
  end

  def run
    begin

      client = AWS::EC2::Client.new aws_config

      def by_instances_status(client)
        if config[:scheme] == 'sensu.aws.ec2'
          config[:scheme] += '.count'
        end

        options = { include_all_instances: true }
        data = client.describe_instance_status(options)

        total = data[:instance_status_set].count
        status = {}

        unless total.nil?
          data[:instance_status_set].each do |value|
            stat = value[:instance_state][:name]
            if status[stat].nil?
              status[stat] = 1
            else
              status[stat] = status[stat] + 1
            end
          end
        end

        unless data.nil?
          # We only return data when we have some to return
          output config[:scheme] + '.total', total
          status.each do |name, count|
            output config[:scheme] + ".#{name}", count
          end
        end
      end

      def by_instances_type(client)
        if config[:scheme] == 'sensu.aws.ec2'
          config[:scheme] += '.types'
        end

        data = {}

        instances = client.describe_instances
        instances[:reservation_set].each do |i|
          i[:instances_set].each do |instance|
            type = instance[:instance_type]
            if data[type].nil?
              data[type] = 1
            else
              data[type] = data[type] + 1
            end
          end
        end

        unless data.nil?
          # We only return data when we have some to return
          data.each do |name, count|
            output config[:scheme] + ".#{name}", count
          end
        end
      end

      if config[:type] == 'instance'
        by_instances_type(client)
      elsif config[:type] == 'status'
        by_instances_status(client)
      end

    rescue => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
