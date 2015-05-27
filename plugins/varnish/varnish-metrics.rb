#! /usr/bin/env ruby
#
#   varnish-metrics
#
# DESCRIPTION:
#   This was tested with varnishstat from Varnish 3.x, but should work fine
#   with 2.x as well, and probably any version that supports '-x' for xml output.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: crack
#   gem: uri
#   gem: json
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   #YELOW Narrow down the list of metrics output default but still output all
#       metrics with a flag.
#
# LICENSE:
#   Copyright 2012 Joe Miller https://github.com/joemiller
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'json'
require 'uri'
require 'crack'

class VarnishMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.varnish"

  option :varnish_name,
         description: 'The varnishd instance to get data from',
         short: '-n VARNISH_NAME',
         long: '--name VARNISH_NAME'

  def graphite_path_sanitize(path)
    # accept only a small set of chars in a graphite path and convert anything else
    # to underscores
    path.gsub(/[^a-zA-Z0-9_-]/, '_')
  end

  def run
    begin
      if config[:varnish_name]
        varnishstat = `varnishstat -x -n #{config[:varnish_name]}`
      else
        varnishstat = `varnishstat -x`
      end
      stats = Crack::XML.parse(varnishstat)
      stats['varnishstat']['stat'].each do |stat|
        path = "#{config[:scheme]}"
        path += '.' + graphite_path_sanitize(stat['type'])    if stat['type']
        path += '.' + graphite_path_sanitize(stat['ident'])   if stat['ident']
        path += '.' + graphite_path_sanitize(stat['name'])
        output path, stat['value']
      end
    rescue => e
      puts "Error: exception: #{e}"
      critical
    end
    ok
  end
end
