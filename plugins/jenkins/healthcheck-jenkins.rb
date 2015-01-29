#! /usr/bin/env ruby
#
#   check-jenkins
#
# DESCRIPTION:
#   This plugin checks that the Jenkins Metrics healthcheck is healthy throughout
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#   gem: json
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2015, Cornel Foltea cornel.foltea@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class JenkinsMetricsHealthChecker < Sensu::Plugin::Check::CLI
  option :server,
         description: 'Jenkins Host',
         short: '-s SERVER',
         long: '--server SERVER',
         default: 'localhost'

  option :uri,
         description: 'Jenkins Metrics Healthcheck URI',
         short: '-u URI',
         long: '--uri URI',
         default: '/metrics/currentUser/healthcheck'

  def run
    r = RestClient::Resource.new("http://#{config[:server]}:8080#{config[:uri]}", timeout: 5).get
    if r.code == 200
      healthchecks = JSON.parse(r)
      healthchecks.each do |_, healthcheck_hash_value|
        if healthcheck_hash_value['healthy'] != true
          critical 'Jenkins Health Parameters not OK'
        end
      end
      ok 'Jenkins Health Parameters are OK'
    else
      critical 'Jenkins Service is not responding'
    end
  rescue Errno::ECONNREFUSED
    critical 'Jenkins Service is not responding'
  rescue RestClient::RequestTimeout
    critical 'Jenkins Service Connection timed out'
  end
end
