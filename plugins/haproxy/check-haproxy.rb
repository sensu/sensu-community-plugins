#!/usr/bin/env ruby
#
# HAProxy Check
# ===
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

  def run
    unless service = ARGV.shift
      unknown 'No service specified'
    end

    haproxy = HAProxy.read_stats('/var/run/haproxy.sock')

    aggregate_names = ["FRONTEND", "BACKEND"]

    service_collection = []
    failed_services = []

    haproxy.stats.each do |srv|
      if srv[:pxname] =~ /#{service}/ && !aggregate_names.include?(srv[:svname])
        service_collection << srv
      end
    end

    if service_collection.empty?
      warning "No services could be found in haproxy matching /#{service}/"
    else
      service_collection.each do |srv|
        if srv[:status] != "UP"
          failed_services << srv
        end
      end
      if failed_services.empty?
        ok "All #{service_collection.size} /#{service}/ services are up"
      else
        critical "These services are not UP: #{failed_services.collect{|srv| srv[:svname]}.join(', ')}"
      end
    end
  end

end
