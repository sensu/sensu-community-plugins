#! /usr/bin/env ruby
#
#   check-sensor
#
# DESCRIPTION:
#   This plugin collects sensor data from an IPMI endpoint.
#   Output is in Graphite format. See the rubyipmi gem docs for
#   a more detailed explanation of how to find and use sensor names.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: ipmi
#   ipmitool or freeipmi package
#
# USAGE:
#   By default the check returns all sensors.  If you want to check
#   just the IPMI temperature sensor on a power supply named
#   't_in_ps0', you do the following.
#
#   check-sensor.rb -u IPMI_USER -p IPMI_PASS -h 10.1.1.1 -s t_in_ps0
#   FQDN.ipmisensor.t_in_ps1 32.000 1416346692
#
# NOTES:
#   Don't use passwords with characters that require escaping (e.g. !)
#   Test your IPMI endpoints first to verify any specified sensor names
#   and that your credentials are working before adding them to a Sensu
#   check.
#
# LICENSE:
#   Matt Mencel <matt@techminer.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rubyipmi'
require 'socket'
require 'timeout'

class CheckSensor < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to .$parent.$child',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.ipmisensor"

  option :sensor,
         description: 'IPMI sensor to gather stats for.  Default is ALL',
         short: '-s SENSOR_NAME',
         long: '--sensor SENSOR_NAME',
         default: 'all'

  option :username,
         description: 'IPMI Username',
         short: '-u IPMI_USERNAME',
         long: '--username IPMI_USERNAME',
         required: true

  option :password,
         description: 'IPMI Password',
         short: '-p IPMI_PASSWORD',
         long: '--password IPMI_PASSWORD',
         required: true

  option :privilege,
         description: 'IPMI privilege level: CALLBACK, USER, OPERATOR, ADMINISTRATOR (defaults to USER)',
         short: '-v PRIVILEGE',
         long: '--privilege PRIVILEGE',
         default: 'USER',
         required: false

  option :host,
         description: 'IPMI Hostname or IP',
         short: '-h IPMI_HOST',
         long: '--host IPMI_HOST',
         required: true

  option :provider,
         description: 'IPMI Tool Provider (ipmitool OR freeipmi).  Default is ipmitool.',
         short: '-i IPMI_PROVIDER',
         long: '--ipmitool IPMI_PROVIDER',
         default: 'ipmitool'

  option :timeout,
         description: 'IPMI connection timeout in seconds (defaults to 30)',
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT',
         default: 30

  def conn
    timeout(config[:timeout].to_i) do
      Rubyipmi.connect(config[:username],
                       config[:password],
                       config[:host],
                       config[:provider],
                       privilege: config[:privilege])
    end
  rescue Timeout::Error
    unknown 'Timeout during IPMI operation.'
  rescue => e
    unknown "An unknown error occured: #{e.inspect}"
  end

  def run
    # #YELLOW
    conn.sensors.list.each do |sensor| # rubocop:disable Style/Next
      if config[:sensor] != 'all'
        next if sensor[1][:name] != config[:sensor]
      end
      name = sensor[1][:name]
      value = sensor[1][:value]

      if name !~ /^error_/
        begin
          value = Float(value)
          output "#{config[:scheme]}.#{name}", value, Time.now.to_i
        rescue TypeError, ArgumentError
          'Not numeric' # Not a numeric value - no point pushing as a metric
        end
      end
    end
    ok
  end
end
