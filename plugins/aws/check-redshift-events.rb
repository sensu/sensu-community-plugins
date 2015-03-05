#! /usr/bin/env ruby
#
# check-redshift-events
#
# DESCRIPTION:
#   This plugin checks amazon redshift clusters for maintenance events
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
#
#   check for instances in maint in us-east-1:
#   ./check-redshift-events.rb -a ${your access key} -s ${your secret access key} -r us-east-1
#
#   check for maint events on a single instance in us-east-1 (skip others):
#   ./check-redshift-events.rb -a ${your access key} -s ${your secret access key} -r us-east-1 -i ${your cluster name}
#
#   check for maint events on multiple instance in us-east-1 (skip others):
#   ./check-redshift-events.rb -a ${your access key} -s ${your secret access key} -r us-east-1 -i ${cluster1,cluster2,cluster3}
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Tim Smith, tim@cozy.co
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'aws-sdk-v1'

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

  option :instances,
         short: '-i INSTANCES',
         long: '--instances INSTANCES',
         description: 'Comma separated list of instances to check. Defaults to all clusters in the region',
         proc: proc { |a| a.split(',') },
         default: []

  # setup a redshift connection using aws-sdk-v1
  def redshift
    @redshift ||= AWS::Redshift::Client.new(
      access_key_id: config[:aws_access_key],
      secret_access_key: config[:aws_secret_access_key],
      region: config[:aws_region])
  end

  # fetch all clusters in the region from AWS
  def all_clusters
    @clusters ||= redshift.describe_clusters[:clusters].map { |c| c[:cluster_identifier] }
  end

  # throw unknown message if the user passed us a missing instance
  def check_missing_instances(instances)
    missing_instances = instances.select { |i| !all_clusters.include?(i) }
    unknown("Passed instance(s): #{missing_instances.join(',')} not found") unless missing_instances.empty?
  end

  # return an array of clusters that are in maintenance
  def clusters_in_maint(clusters)
    maint_clusters = []

    # fetch the last 2 hours of events for each cluster
    clusters.each do |cluster_name|
      events_record = redshift.describe_events(start_time: (Time.now - 7200).iso8601, source_type: 'cluster', source_identifier: cluster_name)

      next if events_record[:events].empty?

      # if the last event is a start maint event then the cluster is still in maint
      maint_clusters.push(cluster_name) if events_record[:events][-1][:event_id] == 'REDSHIFT-EVENT-2003'
    end
    maint_clusters
  end

  def run
    begin
      # make sure passed instances exist and only check those instances
      unless config[:instances].empty?
        check_missing_instances(config[:instances])
        all_clusters.select! { |c| config[:instances].include?(c) }
      end

      maint_clusters = clusters_in_maint(all_clusters)
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
