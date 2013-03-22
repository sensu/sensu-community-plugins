#!/usr/bin/env ruby
#
# Checks SQS messages
# ===
#
# DESCRIPTION:
#   This plugin checks the number of messages in an Amazon Web Services SQS queue.
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin >= 1.5 Ruby gem
#   aws-sdk Ruby gem
#
# Copyright (c) 2013, Justin Lambert <jlambert@letsevenup.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'aws-sdk'

class SQSMsgs < Sensu::Plugin::Check::CLI

  option :aws_access_key,
    :short => '-a AWS_ACCESS_KEY',
    :long => '--aws-access-key AWS_ACCESS_KEY',
    :description => "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
    :required => true

  option :aws_secret_access_key,
    :short => '-s AWS_SECRET_ACCESS_KEY',
    :long => '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
    :description => "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
    :required => true

  option :queue,
    :short => '-q SQS_QUEUE',
    :long => '--queue SQS_QUEUE',
    :description => 'The name of the SQS you want to check the number of messages for',
    :required => true

  option :warning,
    :short  => '-w WARN_NUM',
    :long  => '--warnnum WARN_NUM',
    :description => 'Number of messages in the queue considered to be a warning',
    :required => true

  option :critical,
    :short  => '-c CRIT_NUM',
    :long  => '--critnum CRIT_NUM',
    :description => 'Number of messages in the queue considered to be critical',
    :required => true

  def run
    AWS.config(
      :access_key_id      => config[:aws_access_key],
      :secret_access_key  => config[:aws_secret_access_key])

    sqs = AWS::SQS.new
    messages = sqs.queues.named(config[:queue]).approximate_number_of_messages

    if messages >= config[:critical].to_i
      critical "#{messages} messages in #{config[:queue]} queue"
    elsif messages >= config[:warning].to_i
      warning "#{messages} messages in #{config[:queue]} queue"
    else
      ok "#{messages} messages in #{config[:queue]} queue"
    end
  end

end
