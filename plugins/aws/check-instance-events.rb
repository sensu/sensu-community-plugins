#! /usr/bin/env ruby
#
# check-instance-events
#
# DESCRIPTION:
#   This plugin looks up all instances in an account and alerts if one or more have a scheduled
#   event (reboot, retirement, etc)
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
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
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class CheckInstanceEvents < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY_ID']

  option :use_iam_role,
         short: '-u',
         long: '--use-iam',
         description: 'Use IAM role authenticiation. Instance must have IAM role assigned for this to work'

  option :include_name,
         short: '-n',
         long: '--include-name',
         description: "Includes any offending instance's 'Name' tag in the check output",
         default: false

  option :aws_secret_access_key,
         short: '-s AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
         default: ENV['AWS_SECRET_ACCESS_KEY']

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (such as eu-west-1).',
         default: 'us-east-1'

  def run
    event_instances = []
    aws_config =   {}

    if config[:use_iam_role].nil?
      aws_config.merge!(
      access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key]
      )
    end

    ec2 = AWS::EC2::Client.new(aws_config.merge!(region: config[:aws_region]))
    begin
      # #YELLOW
      ec2.describe_instance_status[:instance_status_set].each do |i| # rubocop:disable Next

        unless i[:events_set].empty?
          # Exclude completed reboots since the events API appearently returns these even after they have been completed:
          # Example:
          #  "events_set": [
          #     {
          #         "code": "system-reboot",
          #         "description": "[Completed] Scheduled reboot",
          #         "not_before": "2015-01-05 12:00:00 UTC",
          #         "not_after": "2015-01-05 18:00:00 UTC"
          #     }
          # ]
          unless i[:events_set].select { |x| x[:code] == 'system-reboot' && x[:description] =~ /\[Completed\]/ }
            event_instances << i[:instance_id]
          end
        end
      end
    rescue => e
      unknown "An error occurred processing AWS EC2 API: #{e.message}"
    end

    if config[:include_name]
      event_instances_with_names = []
      event_instances.each do |id|
        name = ''
        begin
          instance = ec2.describe_instances(instance_ids: [id])
          # Harvests the 'Name' tag for the instance
          name = instance[:reservation_index][id][:instances_set][0][:tag_set].select { |tag| tag[:key] == 'Name' }[0][:value]
        rescue => e
          puts "Issue getting instance details for #{id}.  Exception = #{e}"
        end
        # Pushes 'name(i-xxx)' if the Name tag was found, else it just pushes the id
        event_instances_with_names << (name == '' ? id : "#{name}(#{id})")
      end
      event_instances = event_instances_with_names
    end

    if event_instances.count > 0
      critical("#{event_instances.count} instances #{event_instances.count > 1 ? 'have' : 'has'} upcoming scheduled events: #{event_instances.join(',')}")
    else
      ok
    end
  end
end
