#!/usr/bin/env ruby
#
# Pull puma metrics
#
# Requires app to be running with --control auto --state "/tmp/puma.state"
#
# ===
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'

require 'json'
require 'puma/configuration'
require 'socket'
require 'yaml'

class PumaMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.puma"

  option :state_file,
    :description => "Puma state file",
    :short => "-p STATE_FILE",
    :long => "--state-file SOCKET",
    :default => "/tmp/puma.state"

  def puma_options
    @puma_options ||= begin
      return nil unless File.exists?(config[:state_file])
      YAML.load_file(config[:state_file])['config'].options
    end
  end

  def puma_stats
    stats = Socket.unix(puma_options[:control_url].gsub('unix://', '')) do |socket|
      socket.print("GET /stats?token=#{puma_options[:control_auth_token]} HTTP/1.0\r\n\r\n")
      socket.read
    end

    JSON.parse(stats.split("\r\n").last)
  end

  def run
    puma_stats.map do |k, v|
      output "#{config[:scheme]}.#{k}", v
    end
    ok
  end

end
