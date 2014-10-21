#!/usr/bin/env ruby
#
# Filesize metrics
# ===
#
# Simple wrapper around `stat` for getting file size stats,
# in both, bytes and blocks.
#
# Based on: Curl HTTP Timings metric (Sensu Community Plugins) by Joe Miller
#
# Copyright 2014 Pablo Figue
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'socket'
require 'sensu-plugin/metric/cli'

class FilesizeMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :filepath,
    :short => '-f PATH',
    :long => '--file PATH',
    :description => 'Absolute path to file to measure',
    :required => true

  option :omitblocks,
    :short => '-o',
    :long => '--blocksno',
    :description => 'Don\'t report size in blocks',
    :required => true,
    :default => false

  option :omitbytes,
    :short => '-b',
    :long => '--bytesno',
    :description => 'Don\'t report size in bytes',
    :required => true,
    :default => false

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :required => true,
    :default => "#{Socket.gethostname}.filesize"

  def run

    cmd = "/usr/bin/stat --format=\"%s,%b,\" #{config[:filepath]}"
    output = `#{cmd}`

    (bytes, blocks, empty) = output.split(',')
    unless config[:omitbytes] then
      output "#{config[:scheme]}.bytes", bytes
    end
    unless config[:omitblocks] then
      output "#{config[:scheme]}.blocks", blocks
    end

    ok
  end

end

