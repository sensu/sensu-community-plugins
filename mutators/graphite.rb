#!/usr/bin/env ruby
#
# Graphite
# ===
#
# DESCRIPTION:
#   I extend OnlyCheckOutput mutator specialy for Graphite.
#   This mutator only send event output (so you don't need to use
#   OnlyCheckOutput) and change parameter name if it is hostname
#   for better view in Graphite.
#
# OUTPUT:
#   event output with all dot changed to underline in host name
#   If -r or --reverse parameter given script put hostname in
#   reverse order for better graphite tree view
#
# PLATFORM:
#   all
#
# DEPENDENCIES:
#
#   json Ruby gem
#
# Copyright 2013 Peter Kepes <https://github.com/kepes>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'json'

# parse event
event = JSON.parse(STDIN.read, symbolize_names: true)

if ARGV[0] == '-r' || ARGV[0] == '--reverse'
  puts event[:check][:output].gsub(event[:client][:name], event[:client][:name].split('.').reverse.join('.'))
else
  puts event[:check][:output].gsub(event[:client][:name], event[:client][:name].gsub('.', '_'))
end
