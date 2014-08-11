#!/usr/bin/env ruby
#
# Check for Cassandra Schema Disagreement
# ===
#
# DESCRIPTION:
#   This plugin uses Apache Cassandra's `nodetool` to check to see
#   if any node in the cluster has run into a schema disagreement problem
#
#   See http://www.datastax.com/documentation/cassandra/2.0/cassandra/dml/dml_handle_schema_disagree_t.html
#   for more details
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   Cassandra's nodetool

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckCassandraSchema < Sensu::Plugin::Check::CLI

  option :hostname,
    :short => "-h HOSTNAME",
    :long => "--host HOSTNAME",
    :description => "cassandra hostname",
    :default => "localhost"

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "cassandra JMX port",
    :default => "7199"

  # execute cassandra's nodetool and return output as string
  def nodetool_cmd(cmd)
    `nodetool -h #{config[:hostname]} -p #{config[:port]} #{cmd}`
  end

  def run
    out = nodetool_cmd('describecluster')
    bad_nodes = []
    out.each_line do |line|
      if m = line.match(/\s+UNREACHABLE:\s+(.*)\[(.*)\]\s+$/)
        bad_nodes << m[2]
        next
      end
      if bad_nodes.count > 0
        if m = line.match(/\s+(.*)\[(.*)\]\s+$/)
          bad_nodes << m[2]
        end
      end
    end

    if bad_nodes.count > 0
      critical("nodes " + bad_nodes.join(", ") + " are in schema disagreement")
    else
      ok
    end
  end
end
