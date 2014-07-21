#!/usr/bin/env ruby
#
# Percona Cluster Size Plugin
# ===
#
# This plugin checks the number of servers in the Percona cluster and warns you according to specified limits
#
# Copyright 2012 Chris Alexander <chris.alexander@import.io>, import.io
# Based on the MySQL Health Plugin by Panagiotis Papadomitsos
#
# Depends on mysql:
# gem install mysql
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'mysql'

class CheckPerconaClusterSize < Sensu::Plugin::Check::CLI

  option :user,
         :description => "MySQL User",
         :short => '-u USER',
         :long => '--user USER',
         :default => 'root'

  option :password,
         :description => "MySQL Password",
         :short => '-p PASS',
         :long => '--password PASS',
         :required => true

  option :hostname,
         :description => "Hostname to login to",
         :short => '-h HOST',
         :long => '--hostname HOST',
         :default => 'localhost'

  option :expected,
         :description => "Number of servers expected in the cluster",
         :short => '-e NUMBER',
         :long => '--expected NUMBER',
         :default => 1

  def run
    begin
      db = Mysql.real_connect(config[:hostname], config[:user], config[:password], config[:database])
      cluster_size = db.
          query("SHOW GLOBAL STATUS LIKE 'wsrep_cluster_size'").
          fetch_hash.
          fetch('Value').
          to_i
      critical "Expected to find #{config[:expected]} nodes, found #{cluster_size}" if cluster_size != config[:expected].to_i
      ok "Expected to find #{config[:expected]} nodes and found those #{cluster_size}" if cluster_size == config[:expected].to_i
    rescue Mysql::Error => e
      critical "Percona MySQL check failed: #{e.error}"
    ensure
      db.close if db
    end
  end

end
