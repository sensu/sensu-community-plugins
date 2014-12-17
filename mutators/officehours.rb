#!/usr/bin/env ruby
#
# Office hours mutator
# ===
#
# DESCRIPTION:
#   Check if we're at the office or not. To allow handlers to decide if it
#   should notify or not. For example, don't alert us for development
#   environments on a Saturday at 4am.
#
# OUTPUT:
#   mutated JSON event
#
# PLATFORM:
#   all
#
# DEPENDENCIES:
#
#   json and time Ruby gems
#
# Copyright 2013 Jean-Francois Theroux <failshell@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems'
require 'json'
require 'time'

# parse event
event = JSON.parse(STDIN.read, symbolize_names: true)
t = Time.now

# Verify if we're opened for business
if t.wday.between?(1, 5)
  if t.between?(Time.parse('9:00'), Time.parse('17:00'))
    event.merge!(mutated: true, office_hours: true)
  end
end

# output modified event
puts event.to_json
