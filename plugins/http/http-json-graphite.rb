#! /usr/bin/env ruby
#  encoding: UTF-8
#   http-json-graphite.rb
#
# DESCRIPTION:
#   Hits an HTTP endpoint which emits JSON and pushes data into Graphite.
#
# OUTPUT:
#   Graphite formatted data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#
# USAGE:
#   EX: ./http-json-graphite.rb -u 'http://127.0.0.1:8080/jolokia/read/com\
#   .mchange.v2.c3p0:name=datasource,type=PooledDataSource' -s hostname.c3p0\
#    -m 'Connections::numConnections,BusyConnections::numBusyConnections'\
#    -o 'value'
#
# NOTES:
#   The metric option is a comma separated list of the metric (how it will
#   appear in Graphite) and the JSON key which holds the value you want to
#   graph. The object option is optional and is the name of the JSON object
#   which holds the key/value pairs you want to graph.
#
# LICENSE:
#   phamby@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'socket'
require 'json'
require 'uri'

class HttpJsonGraphite < Sensu::Plugin::Metric::CLI::Graphite
  option :url,
         description: 'Full URL to the endpoint',
         short: '-u URL',
         long: '--url URL',
         default: 'http://localhost:8080'

  option :scheme,
         description: 'Metric naming scheme',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}"

  option :metric,
         description: 'Metric/JSON key pair ex:Connections::numConnections',
         short: '-m METRIC::JSONKEY',
         long: '--metric METRIC::JSONKEY'

  option :object,
         description: 'The JSON object containing the data',
         short: '-o OBJECT',
         long: '--object OBJECT'

  def run
    scheme = "#{config[:scheme]}"
    metric_pair_input = "#{config[:metric]}"
    if config[:object]
      object = "#{config[:object]}"
    end
    url = URI.encode("#{config[:url]}")
    begin
      r = RestClient.get url
      metric_pair_array = metric_pair_input.split(/,/)
      metric_pair_array.each do |m|
        metric, attribute = m.to_s.split(/::/)
        unless object.nil?
          JSON.parse(r)[object].each do |k, v|
            if k == attribute
              output([scheme, metric].join('.'), v)
            end
          end
          JSON.parse(r).each do |k, v|
            if k == attribute
              output([scheme, metric].join('.'), v)
            end
          end
        end
      end
      rescue Errno::ECONNREFUSED
        critical "#{config[:url]} is not responding"
      rescue RestClient::RequestTimeout
        critical "#{config[:url]} Connection timed out"
    end
    ok
  end
end
