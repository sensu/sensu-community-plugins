#! /usr/bin/env ruby
#
#   check-iis-current-connections
#
# DESCRIPTION:
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Windows
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#  Tested on Windows 2012RC2.
#
# LICENSE:
#   Yohei Kawahara <inokara@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckIisCurrentConnections < Sensu::Plugin::Check::CLI
  option :warning,
         short: '-w WARNING',
         proc: proc(&:to_f),
         default: 50

  option :critical,
         short: '-c CRITICAL',
         proc: proc(&:to_f),
         default: 150

  option :site,
         short: '-s sitename',
         default: '_Total'

  def run
    io = IO.popen("typeperf -sc 1 \"Web Service(#{config[:site]})\\Current\ Connections\"")
    current_connection = io.readlines[2].split(',')[1].gsub(/"/, '').to_f
    critical "Current Connectio at #{current_connection}" if current_connection > config[:critical]
    warning "Current Connectio at #{current_connection}" if current_connection > config[:warning]
    ok "Current Connection at #{current_connection}"
  end
end
