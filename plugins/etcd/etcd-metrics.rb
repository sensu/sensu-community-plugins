#!/usr/bin/env ruby
#
# ===
#
# DESCRIPTION:
#   This plugin pulls stats out of an etcd node
#
# PLATFORMS:
#   all
#
# OUTPUT:
#   plain-text
#
# DEPENDENCIES:
#   etcd Ruby gem
#
# Copyright (c) 2014, Sean Clerkin
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'etcd'
require 'socket'

class EtcdMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => 'Metric naming scheme',
    :short => '-s SCHEME',
    :long => '--scheme SCHEME',
    :default => "#{Socket.gethostname}.etcd"

  option :etcd_host,
    :description => 'Etcd host, defaults to localhost',
    :short => '-h HOST',
    :long => '--host HOST',
    :default => 'localhost'

  option :etcd_port,
    :description => 'Etcd port, defaults to 4001',
    :short => '-p PORT',
    :long => '--port PORT',
    :default => '4001'

  option :leader_stats,
    :description => 'Show leader stats',
    :short => '-l',
    :long => '--leader-stats',
    :boolean => true,
    :default => false

  def run
    client = Etcd.client(host: config[:etcd_host], port: config[:etcd_port])
    client.stats(:self).each do |k, v|
      if v.is_a? Integer
        output([config[:scheme], 'self', k].join('.'), v)
      end
    end
    client.stats(:store).each do |k, v|
      output([config[:scheme], 'store', k].join('.'), v)
    end
    if config[:leader_stats]
      client.stats(:leader)['followers'].each do |follower, fv|
        fv.each do |metric, mv|
          mv.each do |submetric, sv|
            output([config[:scheme], 'leader', follower, metric, submetric].join('.'), sv)
          end
        end
      end
    end
    ok
  end
end
