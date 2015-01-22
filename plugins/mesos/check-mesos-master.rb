#! /usr/bin/env ruby
#
#   check-mesos-master
#
# DESCRIPTION:
#   This plugin checks that the master/health url returns 200 OK
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

class MesosMasterNodeStatus < Sensu::Plugin::Check::CLI
  option :server,
         description: 'Mesos Master server',
         short: '-s SERVER',
         long: '--server SERVER',
         default: 'localhost'

  def run
    r = RestClient::Resource.new("http://#{config[:server]}:5050/master/health", timeout: 5).get
    if r.code == 200
      ok 'Mesos Master is up'
    else
      critical 'Mesos Master is not responding'
    end
  rescue Errno::ECONNREFUSED
    critical 'Mesos Master is not responding'
  rescue RestClient::RequestTimeout
    critical 'Mesos Master Connection timed out'
  end
end
