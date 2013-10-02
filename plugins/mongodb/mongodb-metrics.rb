#!/usr/bin/env ruby
#
# Pull MongoDB Stats to Graphite
# ===
# Copyright 2013 github.com/foomatty
# Basics from github.com/mantree/mongodb-graphite-metrics
#
# Depends on ruby mongo driver
# gem install mongo
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'mongo'
include Mongo

class MongoDB < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
    :description => "MongoDB host",
    :long => "--host HOST",
    :default => "localhost"

  option :port,
    :description => "MongoDB port",
    :long => "--port PORT",
    :default => 27017

  option :user,
    :description => "MongoDB user",
    :long => "--user USER",
    :default => nil

  option :password,
    :description => "MongoDB password",
    :long => "--password PASSWORD",
    :default => nil

  option :scheme,
    :description => 'Metric naming scheme',
    :long => "--scheme SCHEME",
    :short => "-s SCHEME",
    :default => "#{Socket.gethostname}.mongodb"

  option :auto,
    :description => "Enables automatic discovery of Mongo processes on the host. Requires netstat",
    :long => "--auto",
    :short => "-a",
    :boolean => true,
    :default => false

  option :naming,
    :description => "Enables usage of setName under repl to determine a name to append after the scheme. Useful with --auto",
    :long => "--name",
    :short => "-n",
    :boolean => true,
    :default => false

  def run
    host = config[:host]
    port = config[:port]
    db_name = 'admin'
    db_user = config[:user]
    db_password = config[:password]
    enable_naming = config[:naming]

    begin
      if config[:auto]
        `netstat -lnp | grep mongo | grep -o "[0-9.]*:#{port}" | cut -d ':' -f 1`.each do |ip_addr|
          getMongoStats(ip_addr, port, db_name, db_user, db_password, enable_naming)
        end 
      else
        getMongoStats(host, port, db_name, db_user, db_password, enable_naming)
      end
      ok
    rescue
      exit(1)
    end
  end

  def getMongoStats(host, port, db_name, db_user, db_password, naming_enabled)
    mongo_client = MongoClient.new(host, port)
    @db = mongo_client.db(db_name)
    @db.authenticate(db_user, db_password) unless db_user.nil?

    @isMaster = {"isMaster" => 1}
    metrics = {}
    _result = @db.command(@isMaster)["ok"] == 1
    serverStatus = @db.command('serverStatus' => 1)
    if serverStatus["ok"] == 1
      if naming_enabled
        serviceName = serverStatus['repl']['setName'].gsub(/rs_p_/, '')
      end
      metrics.update(gatherReplicationMetrics(serverStatus))
      timestamp = Time.now.to_i
      metrics.each do |k, v|
        if serviceName == nil
          output [config[:scheme], k].join("."), v, timestamp
        else
          output [config[:scheme], serviceName, k].join("."), v, timestamp
        end
      end
    end
  end

  def gatherReplicationMetrics(serverStatus)
    serverMetrics = {}
    serverMetrics['lock.ratio'] = "#{sprintf("%.5f", serverStatus['globalLock']['ratio'])}" unless serverStatus['globalLock']['ratio'].nil?

    serverMetrics['lock.queue.total'] = serverStatus['globalLock']['currentQueue']['total']
    serverMetrics['lock.queue.readers'] = serverStatus['globalLock']['currentQueue']['readers']
    serverMetrics['lock.queue.writers'] = serverStatus['globalLock']['currentQueue']['writers']

    serverMetrics['connections.current'] = serverStatus['connections']['current']
    serverMetrics['connections.available'] = serverStatus['connections']['available']

    if serverStatus['indexCounters']['btree'].nil?
      serverMetrics['indexes.missRatio'] = "#{sprintf("%.5f", serverStatus['indexCounters']['missRatio'])}"
      serverMetrics['indexes.hits'] = serverStatus['indexCounters']['hits']
      serverMetrics['indexes.misses'] = serverStatus['indexCounters']['misses']
    else
      serverMetrics['indexes.missRatio'] = "#{sprintf("%.5f", serverStatus['indexCounters']['btree']['missRatio'])}"
      serverMetrics['indexes.hits'] = serverStatus['indexCounters']['btree']['hits']
      serverMetrics['indexes.misses'] = serverStatus['indexCounters']['btree']['misses']
    end

    serverMetrics['cursors.open'] = serverStatus['cursors']['totalOpen']
    serverMetrics['cursors.timedOut'] = serverStatus['cursors']['timedOut']

    serverMetrics['mem.residentMb'] = serverStatus['mem']['resident']
    serverMetrics['mem.virtualMb'] = serverStatus['mem']['virtual']
    serverMetrics['mem.mapped'] = serverStatus['mem']['mapped']
    serverMetrics['mem.pageFaults'] = serverStatus['extra_info']['page_faults']

    serverMetrics['asserts.warnings'] = serverStatus['asserts']['warning']
    serverMetrics['asserts.errors'] = serverStatus['asserts']['msg']
    return serverMetrics
  end

end
