#!/usr/bin/env ruby
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details
#
# Assumes that the instance(s) that the handler runs on is setup with an ec2 iam role that has permission to send to the sns topic
#
# Requires the aws-sdk

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'aws-sdk'

class DashingNotif < Sensu::Handler
  def topic_arn
    settings['sns']['topic_arn']
  end

  def event_name
    "#{@event['client']['name']}/#{@event['check']['name']}"
  end

  def message
    @event['check']['notification'] || @event['check']['output']
  end

  def handle
    sns = AWS::SNS.new

    t = sns.topics[topic_arn]

    if @event['action'].eql?("resolve")
      t.publish("RESOLVED - [#{event_name}] - #{message}.")
    else
      t.publish("ALERT - [#{event_name}] - #{message}.")
    end
  end
end