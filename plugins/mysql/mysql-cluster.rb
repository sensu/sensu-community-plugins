#!/usr/bin/env ruby
#
# MySQL Galera Cluster Size Plugin
# ===
#
# This plugin counts number of members in the galera mysql cluster
# Based on the MySQL Health plugin by Panagiotis Papadomitsos <pj@ezgr.net>
# 
# Copyright 2014 Ismael Serrano <ismael.serrano@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'mysql'

class CheckMySQLCluster < Sensu::Plugin::Check::CLI

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

  option :port,
         :description => "Port to connect to",
         :short => '-P PORT',
         :long => '--port PORT',
         :default => "3306"

  option :socket,
         :description => "Socket to use",
         :short => '-s SOCKET',
         :long => '--socket SOCKET'

  option :clusize,
         :description => "Cluster total size",
         :short => '-S NUMBER',
         :long => '--size NUMBER',
         :default => 3
         
  option :critsize,
         :description => "Cluster size considered critical",
         :short => '-c NUMBER',
         :long => '--critsize NUMBER',
         :default => 2


  def run
    begin
        db = Mysql.real_connect(config[:hostname], config[:user], config[:password], config[:database], config[:port].to_i, config[:socket])
        clusmembers = db.
            query("SHOW STATUS LIKE 'wsrep_cluster_size'").
            fetch_hash.
            fetch('Value').
            to_i
        if clusmembers <= config[:critsize].to_i 
 		      critical "Critical number of nodes in the  MySQL Cluster: #{clusmembers} nodes remain of a total " + config[:clusize].to_s + " nodes "
        elsif clusmembers < config[:clusize].to_i
	        warning "Some nodes of the cluster are down: #{clusmembers} nodes remain of a total " + config[:clusize].to_s + " nodes" 
	      else
        	ok "All nodes up: #{clusmembers} nodes remain of a total " + config[:clusize].to_s + " nodes"
	      end
    rescue Mysql::Error => e
        critical "MySQL check failed: #{e.error}"
    ensure
        db.close if db
    end
  end

end
