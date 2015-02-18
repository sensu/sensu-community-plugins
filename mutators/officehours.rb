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
#   json and time gems
#
# Copyright 2013 Jean-Francois Theroux <failshell@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'json'
require 'time'

# parse event
event = JSON.parse(STDIN.read, symbolize_names: true)
t = Time.now
start_time = '9:00'
end_time =  '17:00'
gmt_offset = '+00:00'

# Verify if we're opened for business
if t.wday.between?(1, 5)
  if t.between?(Time.parse("#{start_time} #{gmt_offset}"), Time.parse("#{end_time} #{gmt_offset}"))
    event.merge!(mutated: true, office_hours: true)
  end
end

# output modified event
puts event.to_json
