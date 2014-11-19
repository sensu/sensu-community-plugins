#!/usr/bin/env ruby
#
# IPMI Sensor Plugin
#
# This plugin collects sensor data from an IPMI endpoint.
# Output is in Graphite format. See the rubyipmi gem docs for
# a more detailed explanation of how to find and use sensor names.
#
# Matt Mencel <matt@techminer.net>
#
# REQUIREMENTS:
#    - rubyipmi gem (https://github.com/logicminds/rubyipmi)
#    - ipmitool or freeipmi package
#
# EXAMPLE:  Check the IPMI temperature sensor on a power supply named 't_in_ps0'.
#    check-sensor.rb -u IPMI_USER -p IPMI_PASS -h 10.1.1.1 -s t_in_ps0
#    FQDN.ipmisensor.t_in_ps1 32.000 1416346692
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rubyipmi'
require 'socket'

class CheckSensor < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.ipmisensor"

  option :sensor,
    :description => "IPMI sensor to gather stats for",
    :short => "-s SENSOR_NAME",
    :long => "--sensor SENSOR_NAME",
    :default => "t_in_ps0"

  option :username,
    :description => "IPMI Username",
    :short => "-u IPMI_USERNAME",
    :long => "--username IPMI_USERNAME"

  option :password,
    :description => "IPMI Password",
    :short => "-p IPMI_PASSWORD",
    :long => "--password IPMI_PASSWORD"

  option :host,
    :description => "IPMI Hostname or IP",
    :short => "-h IPMI_HOST",
    :long => "--host IPMI_HOST"

  option :provider,
    :description => "IPMI Tool Provider (ipmitool OR freeipmi).  Default is ipmitool.",
    :short => "-i IPMI_PROVIDER",
    :long => "--ipmitool IPMI_PROVIDER",
    :default => "ipmitool"

  def conn
    Rubyipmi.connect(config[:username], config[:password], config[:host], config[:provider])
  end

  def run
    output [config[:scheme], config[:sensor]].join("."), conn.sensors.send(config[:sensor])[:value], Time.now.to_i
    ok
  end
end
