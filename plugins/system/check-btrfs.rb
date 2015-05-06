#! /usr/bin/env ruby
#
#   check-btrfs
#
# DESCRIPTION: check btrfs volumes for disk free
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   package/binary: btrfs-tools
#
# USAGE:
#   ./check-btrfs.rb [OPTIONS]
#
# NOTES:
#
# LICENSE:
#   Ben Abrams  devops@adaptiv.io
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckBtrfs < Sensu::Plugin::Check::CLI
  option :warn,
         short: '-w PERCENT',
         description: 'Warn if PERCENT or more of device full',
         proc: proc { |a| a.to_i },
         default: 85

  option :crit,
         short: '-c PERCENT',
         description: 'Critical if PERCENT or more of device full',
         proc: proc { |a| a.to_i },
         default: 95

  option :debug,
         short: '-d',
         long: '--debug',
         description: 'Output debug'

  def initialize
    super
    @crit_dev = []
    @warn_dev = []
    @line_count = 0
  end

  def read_fi
    `sudo btrfs fi show`.split("\n").each do |line|
      begin
        match = line.match(/devid\s+\d+\s+size\s+(\d+([\d\.]+)?)GiB\s+used\s+(\d+([\d\.]+)?)GiB\s+path\s+([\w\/]+)/)
        next unless match
        size = match[1].to_f
        used = match[3].to_f
        dev = match[5]
        percent = used / size * 100
      rescue
        unknown 'Bad btrfs fi show output'
      end
      @line_count += 1
      puts "#{dev}: #{sprintf('%.2f', percent)}% used #{used} size #{size}" if config[:debug]
      if percent >= config[:crit]
        @crit_dev << "#{dev} #{sprintf('%.2f', percent)}%"
      elsif percent >= config[:warn]
        @warn_dev << "#{dev} #{sprintf('%.2f', percent)}%"
      end
    end
  end

  def usage_summary
    (@crit_dev + @warn_dev).join(', ')
  end

  def run
    read_fi
    unknown 'No devices found' unless @line_count > 0
    critical usage_summary unless @crit_dev.empty?
    warning usage_summary unless @warn_dev.empty?
    ok "All devices usage under #{config[:warn]}%"
  end
end
