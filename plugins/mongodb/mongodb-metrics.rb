#!/usr/bin/env ruby
#
# Source: https://github.com/needle-cookbooks/sensu-community-plugins/tree/needle/plugins/mongodb
# 

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'mongo'

class MongoDBMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.mongodb"

  def run
    # Metrics borrowed from hoardd: https://github.com/coredump/hoardd

    @db = Mongo::Connection.new.db('admin')
    timestamp = Time.now.to_i
    server_stats = @db.command({'serverStatus' => 1})

    metrics = {
      :opcounters => {
        :insert => server_stats["opcounters"]["insert"],
        :query => server_stats["opcounters"]["query"],
        :update => server_stats["opcounters"]["update"],
        :delete => server_stats["opcounters"]["delete"],
        :getmore => server_stats["opcounters"]["getmore"],
        :command => server_stats["opcounters"]["command"],
      },

      :indexcounters => {
        :accesses => server_stats["indexCounters"]["btree"]["accesses"],
        :hits => server_stats["indexCounters"]["btree"]["hits"],
        :misses => server_stats["indexCounters"]["btree"]["misses"],
        :resets => server_stats["indexCounters"]["btree"]["resets"],
        :missRatio => server_stats["indexCounters"]["btree"]["missRatio"],
      },

      :flushing => {
        :flushes => server_stats["backgroundFlushing"]["flushes"],
        :average_ms => server_stats["backgroundFlushing"]["average_ms"],
        :last_ms => server_stats["backgroundFlushing"]["last_ms"],
      },

      :cursors => {
        :totalOpen => server_stats["cursors"]["totalOpen"],
        :clientCursors_size => server_stats["cursors"]["clientCursors_size"],
        :timedOut => server_stats["cursors"]["timedOut"],
      },

      :asserts => {
        :regular => server_stats["asserts"]["regular"],
        :warning => server_stats["asserts"]["warning"],
        :msg => server_stats["asserts"]["msg"],
        :user => server_stats["asserts"]["user"],
        :rollover => server_stats["asserts"]["rollover"]
      },
      
      :connections => {
        :current => server_stats["connections"]["current"],
        :available => server_stats["connections"]["available"]
      }
    }


    metrics.each do |parent, children|
      children.each do |child, value|
        output [config[:scheme], parent, child].join("."), value, timestamp
      end
    end
    ok
  end

end
