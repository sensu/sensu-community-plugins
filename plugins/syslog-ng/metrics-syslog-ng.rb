#!/usr/bin/env ruby
#
# Check syslog metrics
# ===
#
# Simple wrapper around syslog-ng-ctl to get stats
#
# Based on: http://dev.nuclearrooster.com/2009/12/07/quick-download-benchmarks-with-curl/
# by Nick Stielau.
#
# Copyright 2014 John Dyer
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# rubocop:disable Metrics/AbcSize, Style/AlignParameters
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'socket'
require 'sensu-plugin/metric/cli'

class SyslogNgMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         required: true,
         default: "#{Socket.gethostname.gsub('.', '_')}.syslog_ng"

  option :ctl_path,
         description: 'Path to syslog-ng-ctl command',
         short: '-p PATH',
         long: '--path PATH',
         required: false,
         default: '/usr/sbin'

  def run
    binary = "#{config[:ctl_path]}/syslog-ng-ctl"
    if File.exist? binary
      cmd = "/usr/bin/sudo #{config[:ctl_path]}/syslog-ng-ctl stats | "
      cmd += 'awk -F\; \'NR!=1 && $1 != "src.none" { '
      cmd += ' if ($2 == "") { t=$3 } else {t=$2} {} '
      cmd += ' if ($5 == "stored") {type="gauge"} else {type="derive"} '
      cmd += ' printf "%s-%s-%s %s %s\n",t,type,$5,$6,systime()}\''

      output = `#{cmd}`

      output.split("\n").each do |line|
        output "#{config[:scheme]}.#{line}"
      end

      ok
    else
      warning "#{binary} missing"
    end
  end
end
