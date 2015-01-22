#! /usr/bin/env ruby
#
# sqs-metrics
#
# DESCRIPTION:
#   Fetch SQS metrics
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   sqs-metrics -q my_queue -a key -k secret
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Eric Heydrick <eheydrick@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'aws-sdk'

class SQSMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :queue,
         description: 'Name of the queue',
         short: '-q QUEUE',
         long: '--queue QUEUE',
         required: true

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: ''

  option :aws_access_key,
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY'

  option :aws_secret_access_key,
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
         short: '-k AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY'

  option :aws_region,
         description: 'AWS Region (such as us-east-1)',
         short: '-r AWS_REGION',
         long: '--aws-region AWS_REGION',
         default: 'us-east-1'

  def run
    if config[:scheme] == ''
      scheme = "aws.sqs.queue.#{config[:queue].gsub('-', '_')}.message_count"
    else
      scheme = config[:scheme]
    end

    begin
      sqs = AWS::SQS.new(
        access_key_id: config[:aws_access_key],
        secret_access_key: config[:aws_secret_access_key],
        region: config[:aws_region]
      )

      messages = sqs.queues.named(config[:queue]).approximate_number_of_messages
      output scheme, messages

    rescue => e
      critical "Error fetching SQS queue metrics: #{e.message}"
    end
    ok
  end
end
