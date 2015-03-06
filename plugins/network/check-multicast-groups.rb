#! /usr/bin/env ruby
#
#   <script name>
#
# DESCRIPTION:
#   what is this thing supposed to do, monitor?  How do alerts or
#   alarms work?
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   <your name>  <your email>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

# !/usr/bin/env ruby
#
# Check multicast groups
# ===
#
# This plugin checks if specific multicast groups are configured
# on specific interfaces. The netstat command is required.
#
# The configurations can be put in the default sensu config directory
# and/or out of the sensu directory, as a JSON file. If the config file
# is not in the sensu directry, -c PATH option must be given.
#
# Example config:
#
#  {
#    "check-multicast-groups": [
#      ["eth0", "224.2.2.4"]
#    ]
#  }
#
# Example output:
#
#  $ ./plugins/network/check-multicast-groups.rb -c ./plugins/network/check-multicast-groups.json
#  CheckMulticastGroups CRITICAL: 1 missing multicast groups:
#  eth0    224.2.2.4
#
# Copyright 2014 Mitsutoshi Aoe <maoe@foldr.in>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'json'
require 'sensu-plugin/check/cli'
require 'sensu-plugin/utils'
require 'set'

class CheckMulticastGroups < Sensu::Plugin::Check::CLI
  include Sensu::Plugin::Utils

  option :config,
         short: '-c PATH',
         long: '--config PATH',
         required: true,
         description: 'Path to a config file'

  def run
    targets = settings['check-multicast-groups'] ||= []
    extras = load_config(config[:config])['check-multicast-groups'] || []
    targets.deep_merge(extras)

    critical 'No target muticast groups are specified.' if targets.empty?

    iface_pat = /[a-zA-Z0-9\.]+/
    refcount_pat = /\d+/
    group_pat = /[a-f0-9\.:]+/ # assumes that -n is given
    pattern = /(#{iface_pat})\s+#{refcount_pat}\s+(#{group_pat})/

    actual = Set.new(`netstat -ng`.scan(pattern))
    expected = Set.new(targets)

    diff = expected.difference(actual)
    if diff.size > 0
      diff_output = diff.map { |iface, addr| "#{iface}\t#{addr}" }.join("\n")
      critical "#{diff.size} missing multicast group(s):\n#{diff_output}"
    end
    ok
  rescue => ex
    critical "Failed to check multicast groups: #{ex}"
  end
end
