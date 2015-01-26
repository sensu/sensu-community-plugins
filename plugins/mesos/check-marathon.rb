#! /usr/bin/env ruby
#
#   check-marathon
#
# DESCRIPTION:
#   This plugin checks that the ping url returns 200 OK
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
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2015, Tom Stockton (tom@stocktons.org.uk)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'

class MarathonNodeStatus < Sensu::Plugin::Check::CLI
  option :server,
         description: 'Marathon Host',
         short: '-s SERVER',
         long: '--server SERVER',
         default: 'localhost'

  def run
    r = RestClient::Resource.new("http://#{config[:server]}:8080/ping", timeout: 5).get
    if r.code == 200
      ok 'Marathon Service is up'
    else
      critical 'Marathon Service is not responding'
    end
  rescue Errno::ECONNREFUSED
    critical 'Marathon Service is not responding'
  rescue RestClient::RequestTimeout
    critical 'Marathon Service Connection timed out'
  end
end
