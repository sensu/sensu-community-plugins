#!/usr/bin/env ruby
# check-docker-containers
# ===
#
# This is a simple check script for Sensu to check the number of a Docker Container
#
# Requires "docker-api" gem
#
# Examples:
#
#   check-docker-container.rb -w 3 -c 3
#     => 1 container running = OK.
#     => 4 container running = CRITICAL
#
#  Author Yohei Kawahara  <inokara@gmail.com>
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'docker'

class CheckDockerContainers < Sensu::Plugin::Check::CLI

  option :url,
    :short => '-u docker host',
    :default => "http://127.0.0.1:4243/"

  option :warn_over,
    :short => '-w N',
    :long => '--warn-over N',
    :description => 'Trigger a warning if over a number',
    :proc => proc {|a| a.to_i }

  option :crit_over,
    :short => '-c N',
    :long => '--critical-over N',
    :description => 'Trigger a critical if over a number',
    :proc => proc {|a| a.to_i }

  option :warn_under,
    :short => '-W N',
    :long => '--warn-under N',
    :description => 'Trigger a warning if under a number',
    :proc => proc {|a| a.to_i },
    :default => 1

  option :crit_under,
    :short => '-C N',
    :long => '--critical-under N',
    :description => 'Trigger a critial if under a number',
    :proc => proc {|a| a.to_i },
    :default => 1

  def run
    Docker.url = "#{config[:url]}"
    conn = Docker::Container.all(:ruuning => true)
    count = conn.size.to_i
    puts "#{count} Running Containers..."

    if !!config[:crit_under] && count < config[:crit_under]
      puts critical
    elsif !!config[:crit_over] && count > config[:crit_over]
      puts critical
    elsif !!config[:warn_under] && count < config[:warn_under]
      puts warning
    elsif !!config[:warn_over] && count > config[:warn_over]
      puts warning
    else
      puts ok
    end
  end
end
