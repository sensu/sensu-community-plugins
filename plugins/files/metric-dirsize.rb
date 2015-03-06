#! /usr/bin/env ruby
#
#   metric-dirsize
#
# DESCRIPTION:
#   Simple wrapper around `du` for getting directory size stats,
#   in real size, apparent size and inodes (when supported).
#
#   Check `du --help` to guess the meaning of real and apparent size.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: socket
#
# USAGE:
#   metric-dirsize.rb --dir /var/backups/postgres/ --real
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Pablo Figue
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'socket'
require 'sensu-plugin/metric/cli'

class DirsizeMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :dirpath,
         short: '-d PATH',
         long: '--dir PATH',
         description: 'Absolute path to directory to measure',
         required: true

  option :real_size,
         short: '-r',
         long: '--real',
         description: 'Report real size (bytes)',
         required: true,
         default: false

  option :apparent_size,
         short: '-a',
         long: '--apparent',
         description: 'Report apparent size (bytes)',
         required: true,
         default: false

  option :inodes,
         short: '-i',
         long: '--inodes',
         description: 'Report inodes used instead of bytes. Not all Linux distributions support this.',
         required: true,
         default: false

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         required: true,
         default: "#{Socket.gethostname}.dirsize"

  def run
    if config[:real_size]
      options = ''
      suffix = 'bytes'
    end
    if config[:apparent_size]
      options = '--bytes'
      suffix = 'bytes'
    end
    if config[:inodes]
      options = '--inodes'
      suffix = 'inodes'
    end

    cmd = "/usr/bin/du #{config[:dirpath]} --summarize #{options} | /usr/bin/awk '{ printf \"%s\",$1 }'"
    figure = `#{cmd}`

    output "#{config[:scheme]}.#{config[:dirpath]}.#{suffix}", figure

    ok
  end
end
