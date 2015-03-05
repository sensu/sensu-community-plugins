#!/usr/bin/env ruby
#
# Office hours mutator
# ===
#
# DESCRIPTION:
#   Check if we're at the office or not. To allow handlers to decide if it
#   should notify or not. For example, don't alert us for development
#   environments on a Saturday at 4am.  Note: Adding this mutator alone
#   will not prevent notification. Handlers must utilize the office_hours
#   value to decide if they should notify or not.
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
# Copyright 2015 Tim Smith <tim@cozy.co>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'json'
require 'time'

# parse event
event = JSON.parse(STDIN.read, symbolize_names: true)
@t = Time.now
@start_time = '9:00'
@end_time =  '17:00'
@gmt_offset = '+0:00'

def office_hours?
  @t.between?(Time.parse("#{@start_time} #{@gmt_offset}"), Time.parse("#{@end_time} #{@gmt_offset}"))
end

def office_day?
  @t.wday.between?(1, 5)
end

# mutate the event based on office hours or not
if office_day? && office_hours?
  event.merge!(mutated: true, office_hours: true)
else
  event.merge!(mutated: true, office_hours: false)
end

# output modified event
puts event.to_json
