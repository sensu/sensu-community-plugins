#!/usr/bin/env ruby
#
# This handler assumes it runs on an ec2 instance with an iam role
# that has permission to send to the sns topic specified in the config.
# This removes the requirement to specify an access key and secret access key.
# See http://docs.aws.amazon.com/IAM/latest/UserGuide/WorkingWithRoles.html
#
# Requires the aws-sdk gem.
#
# Setting required in sns.json
#   topic_are  :  The arn for the destination sns topic
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'aws-sdk'

class SnsNotifier < Sensu::Handler
  def topic_arn
    settings['sns']['topic_arn']
  end

  def region
    settings['sns']['region'] || 'us-east-1'
  end

  def event_name
    "#{@event['client']['name']}/#{@event['check']['name']}"
  end

  def use_ami_role
    use_ami_role = settings['sns']['use_ami_role']
    use_ami_role.nil? ? true : use_ami_role
  end

  def aws_access_key
    settings['sns']['access_key'] || ''
  end

  def aws_access_secret
    settings['sns']['secret_key'] || ''
  end

  def message
    @event['check']['notification'] || @event['check']['output']
  end

  def handle
    if use_ami_role
      AWS.config(region: region)
    else
      AWS.config(access_key_id: aws_access_key,
                 secret_access_key: aws_access_secret,
                 region: region)
    end

    sns = AWS::SNS.new

    t = sns.topics[topic_arn]

    if @event['action'].eql?('resolve')
      subject = "RESOLVED - [#{event_name}]"
      options = { subject: subject }
      t.publish("#{subject} - #{message}", options)
    else
      subject = "ALERT - [#{event_name}]"
      options = { subject: subject }
      t.publish("#{subject} - #{message}", options)
    end
  rescue => e
    puts "Exception occured in SnsNotifier: #{e.message}", e.backtrace
  end
end
