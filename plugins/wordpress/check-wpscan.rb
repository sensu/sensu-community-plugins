#! /usr/bin/env ruby
#
# wpscan check
#
# DESCRIPTION:
#  Runs wpscan against a Wordpress site
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   check-wpscan.rb --url <url>
#
# NOTES:
#   wpscan must be installed
#
# LICENSE:
#   Copyright 2015 Eric Heydrick <eheydrick@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'open3'

class WPScan < Sensu::Plugin::Check::CLI
  option :url,
         description: 'Scan target URL',
         short: '-u URL',
         long: '--url URL',
         required: true

  option :wpscan,
         description: 'Path to wpscan',
         short: '-p PATH',
         long: '--path PATH',
         default: '/opt/wpscan/wpscan.rb'

  option :crit,
         description: 'Critical threshold',
         short: '-c CRITICAL',
         long: '--critical CRITICAL',
         proc: proc(&:to_i),
         default: 1

  option :warn_only,
         description: 'Warn instead of critical on finding vulnerabilities',
         short: '-w',
         long: '--warn-only',
         default: false

  def update_wpscan
    `#{config[:wpscan]} --update`
  end

  def run_wpscan
    vulnerabilities = []

    stdout, result = Open3.capture2("echo Y | #{config[:wpscan]} --url #{config[:url]} --follow-redirection --no-color")

    unknown stdout.split("\n").last unless result.success?

    stdout.each_line do |line|
      line.scan(/\[(.)\](.*)/).each do |match|
        if match[0] == '!'
          vulnerabilities << match[1].strip
        end
      end
    end
    vulnerabilities
  end

  def run
    unknown "wpscan does not exist at #{config[:wpscan]}" unless File.exist?(config[:wpscan])

    update_wpscan

    vulnerabilities = run_wpscan

    if vulnerabilities.size >= config[:crit]
      if config[:warn_only]
        warning vulnerabilities.join("\n")
      else
        critical vulnerabilities.join("\n")
      end
    elsif vulnerabilities.size.zero?
      ok 'No vulnerabilities found'
    end
  end
end
