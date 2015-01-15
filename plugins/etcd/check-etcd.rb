#! /usr/bin/env ruby
#
#   check-etcd
#
# DESCRIPTION:
#   This plugin checks that the stats/self url returns 200OK
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
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class EtcdNodeStatus < Sensu::Plugin::Check::CLI
  option :server,
         description: 'etcd server',
         short: '-s SERVER',
         long: '--server SERVER',
         default: 'localhost'

  def run
    r = RestClient::Resource.new("http://#{config[:server]}:4001/v2/stats/self", timeout: 5).get
    if r.code == 200
      ok 'etcd is up'
    else
      critical 'Etcd is not responding'
    end
  rescue Errno::ECONNREFUSED
    critical 'Etcd is not responding'
  rescue RestClient::RequestTimeout
    critical 'Etcd Connection timed out'
  end
end
