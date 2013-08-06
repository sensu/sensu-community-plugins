#!/usr/bin/env ruby
#
# Fetch ELB latency metrics from CloudWatch
# ===
#
# Copyright 2013 Bashton Ltd http://www.bashton.com/
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# Gets latency metrics from CloudWatch and puts them in Graphite for longer term storage
#
# Needs fog gem
#
# By default fetches statistics from one minute ago.  You may need to fetch further back than this;
# high traffic ELBs can sometimes experience statistic delays of up to 10 minutes.  If you experience this,
# raising a ticket with AWS support should get the problem resolved.
# As a workaround you can use eg -f 300 to fetch data from 5 minutes ago.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'fog'

class ELBLatencyMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :elbname,
    :description => "Name of the Elastic Load Balancer",
    :short => "-n ELB_NAME",
    :long => "--name ELB_NAME"

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => ""

  option :fetch_age,
    :description => "How long ago to fetch metrics for",
    :short => "-f AGE",
    :long => "--fetch_age",
    :default => 60,
    :proc => proc { |a| a.to_i }

  option :aws_access_key,
    :short => '-a AWS_ACCESS_KEY',
    :long => '--aws-access-key AWS_ACCESS_KEY',
    :description => "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
    :required => true

  option :aws_secret_access_key,
    :short => '-k AWS_SECRET_ACCESS_KEY',
    :long => '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
    :description => "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
    :required => true

  option :aws_region,
    :short => '-r AWS_REGION',
    :long => '--aws-region REGION',
    :description => "AWS Region (such as eu-west-1).",
    :default => 'us-east-1'

  def run
    if config[:scheme] == ""
      graphitepath = "#{config[:elbname]}.latency"
    else
      graphitepath = config[:scheme]
    end
    begin
      cw = Fog::AWS::CloudWatch.new(
        :aws_access_key_id      => config[:aws_access_key],
        :aws_secret_access_key  => config[:aws_secret_access_key],
        :region             => config[:aws_region])

      et = Time.now() - config[:fetch_age]
      st = et - 60

      result = cw.get_metric_statistics({
        'Namespace' => 'AWS/ELB',
        'MetricName' => 'Latency',
        'Dimensions' => [{
          'Name' => 'LoadBalancerName',
          'Value' => config[:elbname],
         }],
         'Statistics' => ['Average'],
         'StartTime' => st.iso8601,
         'EndTime' => et.iso8601,
         'Period' => '60'
      })
      latency = result.body['GetMetricStatisticsResult']['Datapoints'][0]
      output graphitepath, latency['Average'], latency['Timestamp'].to_i
    rescue Exception => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end

end
