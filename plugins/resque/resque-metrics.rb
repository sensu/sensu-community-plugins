#!/usr/bin/env ruby
#
# Pull resque metrics
# ===
#
# Copyright 2012 Pete Shima <me@peteshima.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'resque'
require 'resque/failure/redis'

class ResqueMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :hostname,
    :short => "-h HOSTNAME",
    :long => "--host HOSTNAME",
    :description => "Redis hostname",
    :required => true

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "Redis port",
    :default => "6379"

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.resque"

  def run

    redis = Redis.new(:host => config[:hostname], :port => config[:port])
    Resque.redis = redis
    count = Resque::Failure::Redis.count
    info = Resque.info

    Resque.queues.each do |v|
      sz = Resque.size(v)
      output "#{config[:scheme]}.queue.#{v}", sz
    end

    output "#{config[:scheme]}.queues", info[:queues]
    output "#{config[:scheme]}.workers", info[:workers]
    output "#{config[:scheme]}.working", info[:working]
    output "#{config[:scheme]}.failed", count
    output "#{config[:scheme]}.pending", info[:pending]
    output "#{config[:scheme]}.processed", info[:processed]

    ok
  end

end
