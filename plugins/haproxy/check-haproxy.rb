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

def silent_require(buggy_gem)
  dup_stderr = STDERR.dup
  STDERR.reopen('/dev/null')
  require buggy_gem
  STDERR.reopen(dup_stderr)
end

silent_require 'haproxy'

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
  option :socket,
    :short => '-S SOCKET',
    :default => "/var/run/haproxy.sock",
    :description => "Path to HAProxy Socket, default: /var/run/haproxy.sock"

  def run
    if config[:service] or config[:all_services]
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
      percent_up = 100 * services.select {|svc| svc[:status] == 'UP' }.size / services.size
      failed_names = services.reject {|svc| svc[:status] == 'UP' }.map {|svc| svc[:svname] }
      message "UP: #{percent_up}% of #{services.size} /#{config[:service]}/ services" + (failed_names.empty? ? "" : ", DOWN: #{failed_names.join(', ')}")
      if percent_up < config[:crit_percent]
        critical
      elsif percent_up < config[:warn_percent]
        warning
      else
        ok
      end
    end
  end

  def get_services
    haproxy = HAProxy.read_stats(config[:socket])
    if config[:all_services]
      haproxy.stats
    else
      haproxy.stats.select do |svc|
        svc[:pxname] =~ /#{config[:service]}/
      end.reject do |svc|
        ["FRONTEND", "BACKEND"].include?(svc[:svname])
      end
    end
  end

end
