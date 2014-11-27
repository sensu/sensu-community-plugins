#!/usr/bin/env ruby
#
# Check Boundary meter connection health
#
# DESCRIPTION:
# This plugin interrogates a boundary api endpoint for the connection health of meters.
# It reports a list of meters that are currently disconnected.
#
# Based on code from check-chef-nodes.rb

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest_client'
require 'json'

class BoundaryMetersChecker < Sensu::Plugin::Check::CLI
  option :endpoint,
    :description => 'Boundary API endpoint',
    :short => '-e API-ENDPOINT',
    :long => '--endpoint API-ENDPOINT',
    :default => 'api.boundary.com'

  option :org,
    :description => 'Organisation ID',
    :short => '-o ORG-ID',
    :long => '--org-id ORG-ID',
    :required => true

  option :key,
    :description => 'API key',
    :short => '-k API-KEY',
    :long => '--key API-KEY',
    :required => true

  def meter_connected_status
    meters.map do |meter|
      { meter['name'] => meter['connected'] }
    end
  end

  def run
    if all_meters_connected?
      ok 'Boundary connectivity is ok, all meters reporting'
    else
      critical "The following meters are not reporting: #{disconnected_names}"
    end
  end

  private

  def meters
    response = RestClient.get("https://#{config[:key]}:@#{config[:endpoint]}/#{config[:org]}/meters")
    JSON.parse response.body
  end

  def all_meters_connected?
    meter_connected_status.map(&:values).flatten.all? { |x| x == 'true' }
  end

  def disconnected_names
    disconnected = meter_connected_status.select { |meter| meter.values.first == 'false' }
    disconnected.map(&:keys).flatten.sort.join(', ').downcase
  end
end
