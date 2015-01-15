#! /usr/bin/env ruby
#
#   check-fluentd-monitor
#
# DESCRIPTION:
#   This plugin checks fluentd monitor_agent.
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'json'

class CheckFluentdMonitorAgent < Sensu::Plugin::Check::CLI
  option :url,
         short: '-u URL',
         long: '--url URL',
         description: 'A URL to connect to',
         default: 'http://localhost:24220/api/plugins.json'

  option :warn,
         short: '-w WARN',
         proc: proc(&:to_i)

  option :crit,
         short: '-c CRIT',
         proc: proc(&:to_i)

  option :metric,
         short: '--m METRIC',
         long: '--metric METRIC',
         description: 'Check monitor_agent metric'

  def run
    if !config[:metric]
      critical 'No metric setting "buffer_queue_length", "retry_count"...'
    elsif !config[:warn]
      critical 'No "warn" setting'
    elsif !config[:crit]
      critical 'No "crit" setting'
    end

    if config[:url]
      uri = URI.parse(config[:url])
      config[:host] = uri.host
      config[:port] = uri.port
      config[:request_uri] = uri.request_uri
    else
      unknown 'No URL specified'
    end

    begin
      timeout(config[:timeout]) do
        acquire_resource
      end
    rescue Timeout::Error
      critical 'Connection timed out'
    rescue => e
      critical "Connection error: #{e.message}"
    end
  end

  def acquire_resource
    http = Net::HTTP.new(config[:host], config[:port])
    response = http.get(config[:request_uri])
    result = JSON.parse(response.body)

    result['plugins'].each do |r|
      next if r[config[:metric]].nil?
      critical "plugin_id #{r['plugin_id']} #{config[:metric]} #{r[config[:metric]]}" if r[config[:metric]] > config[:crit]
      warning "plugin_id #{r['plugin_id']} #{config[:metric]} #{r[config[:metric]]}" if r[config[:metric]] > config[:warn]
    end
    ok
  end
end
