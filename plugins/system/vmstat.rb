#!/usr/bin/env ruby
#
# Copyright 2011 Sonian Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Chef Client Plugin
# ===
#
# This plugin uses vmstat to collect basic system metrics, produces
# a JSON document.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'json'

def convert_integers(values)
  values.each_with_index do |value, index|
    begin
      converted = Integer(value)
      values[index] = converted
    rescue ArgumentError
    end
  end
  values
end

result = convert_integers(`vmstat`.split("\n")[2].split(" "))

procs = {
  :waiting => result[0],
  :uninterruptible => result[1]
}

memory = {
  :swap_used => result[2],
  :free => result[3],
  :inactive => result[4],
  :active => result[5]
}

swap = {
  :in => result[6],
  :out => result[7]
}

io = {
  :received => result[8],
  :sent => result[9]
}

system = {
  :interrupts_per_second => result[10],
  :context_switches_per_second => result[11]
}

cpu = {
  :user => result[12],
  :system => result[13],
  :idle => result[14],
  :waiting => result[15]
}

all = {
  :timestamp => Time.now.to_i,
  :procs => procs,
  :memory => memory,
  :swap => swap,
  :io => io,
  :system => system,
  :cpu => cpu
}

puts all.to_json
