#!/usr/bin/env ruby
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
#implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Chef Client Plugin
# ===
#
# This plugin checks to see if the OpsCode Chef client daemon is running
#

`which tasklist`
case
when $? == 0
  procs = `tasklist`
else
  procs = `ps aux`
end
running = false
procs.each_line do |proc|
  running = true if proc.include?('chef-client')
end
if running
  puts 'CHEF CLIENT - OK - Chef client daemon is running'
  exit 0
else
  puts 'CHEF CLIENT - WARNING - Chef client daemon is NOT running'
  exit 1
end
