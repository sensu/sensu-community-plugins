#!/usr/bin/env ruby
#
# System Temperature Plugin
# ===
#
# This plugin uses sensors to collect basic system metrics, produces
# Graphite formated output.
#
# Copyright 2012 Wantudu SL <dsuarez@wantudu.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# Requires lm-sensors
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class Sensors < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.sensors"

  def run
    raw = `sensors`

    sections = raw.split("\n\n")

    metrics = {}

    sections.each do |section|
      section.split("\n").drop(1).each do |line|
        begin
          key, value = line.split(":")
          key = key.downcase.gsub(/\s/, '')
          if key[0 ..3] == "temp" || key[0 .. 3] == "core"
            value.strip =~ /[\+\-]?(\d+(\.\d)?)/
            value = $1 # rubocop:disable PerlBackrefs
            metrics[key] = value
          end
        rescue
          print "malformed section from sensors: #{line}" + "\n"
        end
      end
    end

    timestamp = Time.now.to_i

    metrics.each do |key, value|
        output [config[:scheme], key].join("."), value, timestamp
    end

    ok
  end

end
