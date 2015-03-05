#! /usr/bin/env ruby
#
#  System User Percentage Metric Plugin
#
# DESCRIPTION:
#   Produces Graphite output of sum of %CPU over all processes by user.
#   E.g., if user joe is running two processes, each using 10% CPU, and
#   jane is running one process using 50% CPU, output will be:
#
#   joe 20.0 (timestamp)
#   jane 50.0 (timestamp)
#
# OUTPUT:
#   Graphite metric data.
#
# PLATFORMS:
#   Linux, BSD, OS X
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: socket
#
# USAGE:
#   ./user-pct-usage-metrics.rb --ignore_inactive true
# NOTES:
#
# LICENSE:
#   John VanDyk <sensu@sysarchitects.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class UserPercent < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme prepended to .username',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.user_percent"

  option :ignore_inactive,
         description: 'Boolean. If true, ignore users using 0% CPU',
         long: '--ignore_inactive',
         default: true

  option :uid,
         description: 'Boolean. If true, uses uid instead of username',
         long: '--uid',
         default: false

  def run
    timestamp = Time.now.to_i
    usertype = config[:uid] ? 'uid' : 'user'
    pslist = `ps -A -o #{usertype}= -o %cpu= -o %mem=`

    users = {}
    pslist.lines.each do |line|
      user, cpu, mem = line.split
      users[user] = {} unless users[user]
      h = { 'cpu' => cpu.to_f, 'mem' => mem.to_f }
      users[user] = users[user].merge(h) { |_key, oldval, newval| newval + oldval }
    end

    if config[:ignore_inactive]
      users.delete_if { |_key, value| value == 0 }
    end

    users.each do |user, h|
      h.each do |key, value|
        output [config[:scheme], user].join(".#{key}."), value, timestamp
      end
    end
    ok
  end
end
