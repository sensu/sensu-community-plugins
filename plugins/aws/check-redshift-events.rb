#! /usr/bin/env ruby
#
# check-redshift-events
#
# DESCRIPTION:
#   This plugin checks redshift clusters for maintenance events
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

class CheckRedshiftEvents < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
         default: ENV['AWS_ACCESS_KEY_ID']

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
    redshift = AWS::Redshift::Client.new(
      access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region])

    begin
      # fetch all clusters identifiers
      clusters = redshift.describe_clusters[:clusters].map { |c| c[:cluster_identifier] }
      maint_clusters = []

      # fetch the last 2 hours of events for each cluster
      clusters.each do |cluster_name|
        events_record = redshift.describe_events(start_time: (Time.now - 7200).iso8601, source_type: 'cluster', source_identifier: cluster_name)

        next if events_record[:events].empty?

        # if the last event is a start maint event then the cluster is still in maint
        maint_clusters.push(cluster_name) if events_record[:events][-1][:event_id] == 'REDSHIFT-EVENT-2003'
      end
    rescue => e
      unknown "An error occurred processing AWS Redshift API: #{e.message}"
    end

    if maint_clusters.empty?
      ok
    else
      critical("Clusters in maintenance: #{maint_clusters.join(',')}")
    end
  end
end
