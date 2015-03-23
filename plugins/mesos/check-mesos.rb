#! /usr/bin/env ruby
#
#   check-mesos
#
# DESCRIPTION:
#   This plugin checks that the health url returns 200 OK
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

class MesosNodeStatus < Sensu::Plugin::Check::CLI
  option :server,
         description: 'Mesos Host',
         short: '-s SERVER',
         long: '--server SERVER',
         default: 'localhost'

  option :mode,
         description: 'master or slave',
         short: '-m MODE',
         long: '--mode MODE',
         required: true

  def run
    case config[:mode]
    when 'master'
      port = '5050'
      uri = '/master/health'
    when 'slave'
      port = '5051'
      uri = '/slave(1)/health'
    end
    begin
      r = RestClient::Resource.new("http://#{config[:server]}:#{port}#{uri}", timeout: 5).get
      if r.code == 200
        ok "Mesos #{config[:mode]} is up"
      else
        critical "Mesos #{config[:mode]} is not responding"
      end
    rescue Errno::ECONNREFUSED
      critical "Mesos #{config[:mode]} is not responding"
    rescue RestClient::RequestTimeout
      critical "Mesos #{config[:mode]} Connection timed out"
    end
  end
end
