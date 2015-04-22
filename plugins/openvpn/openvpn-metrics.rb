#! /usr/bin/env ruby
#
#   openvpn-metrics
#
# DESCRIPTION:
#   Requires the admin interface to be enabled on the OpenVPN server.
#   Opens a telnet connection to the admin interface, collects data,
#   and sends it back to Sensu.
#
#   Some command-line options (either the builtin defaults
#   or the options sent by sensu-server) can be overriden locally
#   by a .json config file, like this:
#
#   $ cat /etc/sensu/conf.d/openvpn-metrics.json
#   {
#     "openvpn-metrics": {
#       "host": "1.2.3.4",
#       "port": "12345",
#       "service": "users"
#     }
#   }
#
#   This is to allow different VPN servers to bind the admin interface to
#   different host:port combos, while still sending the same command to
#   all sensu-client instances.
#
#   In other words, for --host and --port the order of importance, starting
#   with the most important, is:
#
#   1. Values defined locally in sensu/conf.d/*.json
#   2. Command line options passed via --host and --port
#   3. Built-in defaults (displayed with --help)
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: net
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

require 'sensu-plugin/metric/cli'
require 'sensu-plugin/utils'
require 'net/telnet'

class OpenvpnGraphite < Sensu::Plugin::Metric::CLI::Graphite
  include Sensu::Plugin::Utils

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.openvpn"

  option :host,
         description: 'Host to connect to',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'Port to connect to',
         short: '-p PORT',
         long: '--port PORT',
         default: 1195

  option :timeout,
         description: 'Connection timeout',
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT',
         default: 10

  option :prompt,
         description: 'Initial prompt for OpenVPN admin interface',
         short: '-r PROMPT',
         long: '--prompt PROMPT',
         default: ">INFO:OpenVPN Management Interface Version 1 -- type 'help' for more info\n"

  option :service,
         description: 'If more than one openvpn service is running here, name this one to identify it',
         short: '-e SERVICE',
         long: '--service SERVICE',
         default: 'main'

  def run
    # Are these options overriden locally in .json?
    if defined? settings['openvpn-metrics']['host']
      def_host = settings['openvpn-metrics']['host']
    else
      def_host = config[:host]
    end

    if defined? settings['openvpn-metrics']['port']
      def_port = settings['openvpn-metrics']['port']
    else
      def_port = config[:port]
    end

    if defined? settings['openvpn-metrics']['service']
      def_service = settings['openvpn-metrics']['service']
    else
      def_service = config[:service]
    end

    # collect data
    # telnet into admin interface
    vpn = Net::Telnet.new('Host' => def_host,
                          'Port' => def_port,
                          'Timeout' => config[:timeout],
                          'Telnetmode' => false,
                          'Prompt' => config[:prompt])

    # issue stats command
    status = vpn.cmd('String' => 'load-stats',
                     'Match' => /^SUCCESS: nclients=[0-9]+,bytesin=[0-9]+,bytesout=[0-9]+/).lines[1].chomp

    vpn.close

    # Example output from actual telnet session:
    #
    # >INFO:OpenVPN Management Interface Version 1 -- type 'help' for more info
    # load-stats
    # SUCCESS: nclients=1,bytesin=371632,bytesout=176455

    # grok output
    stat_fields = status.split(',')
    nclients = stat_fields[0].split('=')[1]
    bytesin = stat_fields[1].split('=')[1]
    bytesout = stat_fields[2].split('=')[1]

    # send metrics to Sensu
    output "#{config[:scheme]}.#{def_service}.nclients", nclients
    output "#{config[:scheme]}.#{def_service}.bytesin", bytesin
    output "#{config[:scheme]}.#{def_service}.bytesout", bytesout

    ok
  end
end
