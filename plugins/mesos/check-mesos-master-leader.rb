#! /usr/bin/env ruby
#
#   check-mesos-master-leader
#
# DESCRIPTION:
#   This plugin checks if this server is the Mesos Master Leader
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
#   Copyright 2015, Tom Stockton (tom@stocktons.org.uk)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class MesosMasterNodeStatus < Sensu::Plugin::Check::CLI
  option :server,
         description: 'Mesos Master Leader Status',
         short: '-s SERVER',
         long: '--server SERVER',
         default: 'localhost'

  def run
    r = RestClient::Resource.new("http://#{config[:server]}:5050/master/state.json", timeout: 5).get
    h = JSON.parse(r)
    if h['leader'] == h['pid']
      ok 'This server is the Mesos Master Leader'
    else
      warning 'This server is not the Mesos Master Leader'
    end
  rescue Errno::ECONNREFUSED
    critical 'Mesos Master is not responding'
  rescue RestClient::RequestTimeout
    critical 'Mesos Master Connection timed out'
  end
end
