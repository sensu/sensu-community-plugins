#! /usr/bin/env ruby
#
#   check-haproxy
#
# DESCRIPTION:
#   Defaults to checking if ALL services in the given group are up; with
#   -1, checks if ANY service is up. with -A, checks all groups.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: socket
#   gem: csv
#   gem: uri
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2011 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'socket'
require 'csv'
require 'uri'

class CheckHAProxy < Sensu::Plugin::Check::CLI
  option :stats_source,
         short: '-S HOSTNAME|SOCKETPATH',
         long: '--stats HOSTNAME|SOCKETPATH',
         description: 'HAproxy web stats hostname or path to stats socket',
         required: true
  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'HAproxy web stats port',
         default: '80'
  option :path,
         short: '-q STATUSPATH',
         long: '--statspath STATUSPATH',
         description: 'HAproxy web stats path',
         default: '/'
  option :username,
         short: '-u USERNAME',
         long: '--user USERNAME',
         description: 'HAproxy web stats username'
  option :password,
         short: '-p PASSWORD',
         long: '--pass PASSWORD',
         description: 'HAproxy web stats password'
  option :warn_percent,
         short: '-w PERCENT',
         boolean: true,
         default: 50,
         proc: proc(&:to_i),
         description: 'Warning Percent, default: 50'
  option :crit_percent,
         short: '-c PERCENT',
         boolean: true,
         default: 25,
         proc: proc(&:to_i),
         description: 'Critical Percent, default: 25'
  option :session_warn_percent,
         short: '-W PERCENT',
         boolean: true,
         default: 75,
         proc: proc(&:to_i),
         description: 'Session Limit Warning Percent, default: 75'
  option :session_crit_percent,
         short: '-C PERCENT',
         boolean: true,
         default: 90,
         proc: proc(&:to_i),
         description: 'Session Limit Critical Percent, default: 90'
  option :all_services,
         short: '-A',
         boolean: true,
         description: 'Check ALL Services, flag enables'
  option :missing_ok,
         short: '-m',
         boolean: true,
         description: 'Missing OK, flag enables'
  option :service,
         short: '-s SVC',
         description: 'Service Name to Check'
  option :exact_match,
         short: '-e',
         boolean: false,
         description: 'Whether service name specified with -s should be exact match or not'

  def run
    if config[:service] || config[:all_services]
      services = acquire_services
    else
      unknown 'No service specified'
    end

    if services.empty?
      message "No services matching /#{config[:service]}/"
      if config[:missing_ok]
        ok
      else
        warning
      end
    else
      percent_up = 100 * services.select { |svc| svc[:status] == 'UP' || svc[:status] == 'OPEN' }.size / services.size
      failed_names = services.reject { |svc| svc[:status] == 'UP' || svc[:status] == 'OPEN' }.map { |svc| svc[:svname] }
      critical_sessions = services.select { |svc| svc[:slim].to_i > 0 && (100 * svc[:scur].to_f / svc[:slim].to_f) > config[:session_crit_percent] }
      warning_sessions = services.select { |svc| svc[:slim].to_i > 0 && (100 * svc[:scur].to_f / svc[:slim].to_f) > config[:session_warn_percent] }

      status = "UP: #{percent_up}% of #{services.size} /#{config[:service]}/ services" + (failed_names.empty? ? '' : ", DOWN: #{failed_names.join(', ')}")
      if percent_up < config[:crit_percent]
        critical status
      elsif !critical_sessions.empty?
        critical status + '; Active sessions critical: ' + critical_sessions.map { |s| "#{s[:scur]} #{s[:svname]}" }.join(', ')
      elsif percent_up < config[:warn_percent]
        warning status
      elsif !warning_sessions.empty?
        warning status + '; Active sessions warning: ' + warning_sessions.map { |s| "#{s[:scur]} #{s[:svname]}" }.join(', ')
      else
        ok status
      end
    end
  end

  def acquire_services
    uri = URI.parse(config[:stats_source])

    if uri.is_a?(URI::Generic) && File.socket?(uri.path)
      srv = UNIXSocket.open(config[:stats_source])
      srv.write("show stat\n")
      out = srv.read
      srv.close
    else
      res = Net::HTTP.start(config[:stats_source], config[:port]) do |http|
        req = Net::HTTP::Get.new("/#{config[:path]};csv;norefresh")
        unless config[:username].nil?
          req.basic_auth config[:username], config[:password]
        end
        http.request(req)
      end
      unless res.code.to_i == 200
        unknown "Failed to fetch from #{config[:stats_source]}:#{config[:port]}/#{config[:path]}: #{res.code}"
      end

      out = res.body
    end

    parsed = CSV.parse(out, skip_blanks: true)
    keys = parsed.shift.reject(&:nil?).map { |k| k.match(/(\w+)/)[0].to_sym }
    haproxy_stats = parsed.map { |line| Hash[keys.zip(line)] }

    if config[:all_services]
      haproxy_stats
    else
      regexp = config[:exact_match] ? Regexp.new("^#{config[:service]}$") : Regexp.new("#{config[:service]}")
      haproxy_stats.select do |svc|
        svc[:pxname] =~ regexp
        # #YELLOW
      end.reject do |svc| # rubocop: disable MultilineBlockChain
        %w(FRONTEND BACKEND).include?(svc[:svname])
      end
    end
  end
end
