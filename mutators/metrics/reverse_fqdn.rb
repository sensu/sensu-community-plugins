#!/usr/bin/env ruby
#
# Takes the FQDN of and reverses it to enable servers that lives under
# the same subdomin to be present next to each other.
# E.g the key
# machine-01.mongodb.database.domain.com.load_avg.one will
# will be mutated into
# com.domain.database.mongodb.machine-01.load_avg.one
#
# Simon Johansson (simon@simonjohansson.com)
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'json'

event = JSON.parse(STDIN.read, :symbolize_names => true)

client_FQDN = event[:client][:name]
client_FQDN_for_graphite = ((client_FQDN.split '.').reverse).join '.'

puts event[:check][:output].gsub(client_FQDN, client_FQDN_for_graphite)
