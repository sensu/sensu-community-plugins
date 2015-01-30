#! /usr/bin/env ruby
#
#   mesos-metrics
#
# DESCRIPTION:
#   This plugin extracts the stats from a mesos master or slave
#
# OUTPUT:
#    metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#   gem: socket
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
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'socket'
require 'json'

class MesosMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :mode,
         description: 'master or slave',
         short: '-m MODE',
         long: '--mode MODE',
         required: true

  option :scheme,
         description: 'Metric naming scheme',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}"

  option :server,
         description: 'Mesos Host',
         short: '-h SERVER',
         long: '--host SERVER',
         default: 'localhost'

  def run
    case config[:mode]
    when 'master'
      port = '5050'
      uri = '/master/stats.json'
    when 'slave'
      port = '5051'
      uri = '/slave(1)/stats.json'
    end
    scheme = "#{config[:scheme]}.mesos-#{config[:mode]}"
    begin
      r = RestClient::Resource.new("http://#{config[:server]}:#{port}#{uri}", timeout: 5).get
      JSON.parse(r).each do |k, v|
        k_copy = k.tr('/', '.')
        output([scheme, k_copy].join('.'), v)
      end
    rescue Errno::ECONNREFUSED
      critical "Mesos #{config[:mode]} is not responding"
    rescue RestClient::RequestTimeout
      critical "Mesos #{config[:mode]} Connection timed out"
    end
    ok
  end
end
