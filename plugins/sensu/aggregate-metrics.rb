#!/usr/bin/env ruby
#
# Aggregate Metrics
#
# Walks the /aggregates API to return metrics for
# the aggregated output states of each check.
#
# sensu.aggregates.some_aggregated_check.ok 125 1380251999
# sensu.aggregates.some_aggregated_check.warning  0 1380251999
# sensu.aggregates.some_aggregated_check.critical 0 1380251999
# sensu.aggregates.some_aggregated_check.unknown  0 1380251999
# sensu.aggregates.some_aggregated_check.total  125 1380251999
# ===
#
# Authors
# ===
# Sean Porter, @portertech
# Nick Stielau, @nstielau
#
# Copyright 2013 Nick Stielau
# Copyright 2012 Sonian, Inc.
#
# Released under the same terms as Sensu (the MIT license); see
# LICENSE for details.

require 'rubygems'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'json'

class AggregateMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :api,
         short: '-a URL',
         long: '--api URL',
         description: 'Sensu API URL',
         default: 'http://localhost:4567'

  option :user,
         short: '-u USER',
         long: '--user USER',
         description: 'Sensu API USER'

  option :password,
         short: '-p PASSOWRD',
         long: '--password PASSWORD',
         description: 'Sensu API PASSWORD'

  option :timeout,
         short: '-t SECONDS',
         long: '--timeout SECONDS',
         description: 'Sensu API connection timeout in SECONDS',
         proc: proc(&:to_i),
         default: 30

  option :age,
         short: '-A SECONDS',
         long: '--age SECONDS',
         description: 'Minimum aggregate age in SECONDS, time since check request issued',
         default: 30,
         proc: proc(&:to_i)

  option :scheme,
         description: 'Metric naming scheme',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.sensu.aggregates"

  option :debug,
         long: '--debug',
         description: 'Verbose output'

  def api_request(resource)
    request = RestClient::Resource.new(config[:api] + resource, timeout: config[:timeout],
                                                                user: config[:user],
                                                                password: config[:password])
    JSON.parse(request.get, symbolize_names: true)
  rescue RestClient::ResourceNotFound
    warning "Resource not found: #{resource}"
  rescue Errno::ECONNREFUSED
    warning 'Connection refused'
  rescue RestClient::RequestFailed
    warning 'Request failed'
  rescue RestClient::RequestTimeout
    warning 'Connection timed out'
  rescue RestClient::Unauthorized
    warning 'Missing or incorrect Sensu API credentials'
  rescue JSON::ParserError
    warning 'Sensu API returned invalid JSON'
  end

  def acquire_checks
    uri = '/aggregates'
    checks = api_request(uri)
    puts "Checks: #{checks.inspect}" if config[:debug]
    checks
  end

  def get_aggregate(check)
    uri = "/aggregates/#{check}"
    issued = api_request(uri + "?age=#{config[:age]}")
    # #YELLOW
    unless issued.empty? # rubocop:disable UnlessElse
      issued_sorted = issued.sort
      time = issued_sorted.pop
      # #YELLOW
      unless time.nil? # rubocop:disable UnlessElse
        uri += "/#{time}"
        [time, api_request(uri)]
      else
        warning "No aggregates older than #{config[:age]} seconds"
      end
    else
      warning "No aggregates for #{check}"
    end
  end

  def run
    acquire_checks.each do |check|
      timestamp, aggregate = get_aggregate(check[:check])
      puts "#{check[:check]} aggregates: #{aggregate}" if config[:debug]
      aggregate.each do |result, count|
        output "#{config[:scheme]}.#{check[:check]}.#{result}", count, timestamp
      end
    end
    ok
  end
end
