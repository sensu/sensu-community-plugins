#!/usr/bin/env ruby
#
# HAProxy Check
# ===
#
# Defaults to checking if ALL services in the given group are up; with
# -1, checks if ANY service is up. with -A, checks all groups.
#
# Updated: To add -S to allow for different named sockets
#
# Copyright 2011 Sonian, Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'socket'
require 'csv'

class CheckHAProxy < Sensu::Plugin::Check::CLI

  option :warn_percent,
    :short => '-w PERCENT',
    :boolean => true,
    :default => 50,
    :proc => proc {|a| a.to_i },
    :description => "Warning Percent, default: 50"
  option :crit_percent,
    :short => '-c PERCENT',
    :boolean => true,
    :default => 25,
    :proc => proc {|a| a.to_i },
    :description => "Critical Percent, default: 25"
  option :session_warn_percent,
    :short => '-W PERCENT',
    :boolean => true,
    :default => 75,
    :proc => proc {|a| a.to_i },
    :description => "Session Limit Warning Percent, default: 75"
  option :session_crit_percent,
    :short => '-C PERCENT',
    :boolean => true,
    :default => 90,
    :proc => proc {|a| a.to_i },
    :description => "Session Limit Critical Percent, default: 90"
  option :all_services,
    :short => '-A',
    :boolean => true,
    :description => "Check ALL Services, flag enables"
  option :missing_ok,
    :short => '-m',
    :boolean => true,
    :description => "Missing OK, flag enables"
  option :service,
    :short => '-s SVC',
    :description => "Service Name to Check"
  option :exact_match,
    :short => '-e',
    :boolean => false,
    :description => "Whether service name specified with -s should be exact match or not"
  option :socket,
    :short => '-S SOCKET',
    :default => "/var/run/haproxy.sock",
    :description => "Path to HAProxy Socket, default: /var/run/haproxy.sock"

  def run
    if config[:service] || config[:all_services]
      services = get_services
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
      percent_up = 100 * services.select {|svc| svc[:status] == 'UP' || svc[:status] == 'OPEN' }.size / services.size
      failed_names = services.reject {|svc| svc[:status] == 'UP' || svc[:status] == 'OPEN' }.map {|svc| svc[:svname] }
      critical_sessions = services.select{ |svc| svc[:slim].to_i > 0 && (100 * svc[:scur].to_f / svc[:slim].to_f) > config[:session_crit_percent] }
      warning_sessions = services.select{ |svc| svc[:slim].to_i > 0 && (100 * svc[:scur].to_f / svc[:slim].to_f) > config[:session_warn_percent] }

      status = "UP: #{percent_up}% of #{services.size} /#{config[:service]}/ services" + (failed_names.empty? ? "" : ", DOWN: #{failed_names.join(', ')}")
      if percent_up < config[:crit_percent]
        critical status
      elsif !critical_sessions.empty?
        critical status + "; Active sessions critical: " + critical_sessions.map{|s| "#{s[:scur]} #{s[:svname]}"}.join(', ')
      elsif percent_up < config[:warn_percent]
        warning status
      elsif !warning_sessions.empty?
        warning status + "; Active sessions warning: " + warning_sessions.map{|s| "#{s[:scur]} #{s[:svname]}"}.join(', ')
      else
        ok status
      end
    end
  end

  def get_services
    if File.socket?(config[:socket])
      srv = UNIXSocket.open(config[:socket])
      srv.write("show stat\n")
      out = srv.read
      srv.close

      parsed = CSV.parse(out, {:skip_blanks => true})
      keys = parsed.shift.reject{|k| k.nil?}.map{|k| k.match(/(\w+)/)[0].to_sym}
      haproxy_stats = parsed.map{|line| Hash[keys.zip(line)]}
    else
      critical "Not a valid HAProxy socket: #{config[:socket]}"
    end

    if config[:all_services]
      haproxy_stats
    else
      regexp = config[:exact_match] ? Regexp.new("^#{config[:service]}$") : Regexp.new("#{config[:service]}")
      haproxy_stats.select do |svc|
        svc[:pxname] =~ regexp
      end.reject do |svc|
        ["FRONTEND", "BACKEND"].include?(svc[:svname])
      end
    end
  end

end
