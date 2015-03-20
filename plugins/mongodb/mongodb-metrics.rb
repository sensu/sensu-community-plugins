#! /usr/bin/env ruby
#
#   mongodb-metrics
#
# DESCRIPTION:
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: mongo
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Basics from github.com/mantree/mongodb-graphite-metrics
#
# LICENSE:
#   Copyright 2013 github.com/foomatty
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'mongo'
include Mongo

class MongoDB < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         description: 'MongoDB host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'MongoDB port',
         long: '--port PORT',
         default: 27_017

  option :user,
         description: 'MongoDB user',
         long: '--user USER',
         default: nil

  option :password,
         description: 'MongoDB password',
         long: '--password PASSWORD',
         default: nil

  option :scheme,
         description: 'Metric naming scheme',
         long: '--scheme SCHEME',
         short: '-s SCHEME',
         default: "#{Socket.gethostname}.mongodb"

  option :ssl,
         description: 'Use SSL to connect',
         long: '--ssl',
         default: false

  option :ssl_cert,
         description: 'SSL certificate (optional)',
         long: '--ssl_cert /path/to/cert',
         default: nil

  option :ssl_ca_cert,
         description: 'SSL CA certificate (optional)',
         long: '--ssl_ca_cert /path/to/ca_cert',
         default: nil

  def run
    host = config[:host]
    port = config[:port]
    db_name = 'admin'
    db_user = config[:user]
    db_password = config[:password]

    ssl_opts = {}
    ssl_opts[:ssl] = config[:ssl]

    if config[:ssl]
      if config[:ssl_cert]
        ssl_opts[:ssl_cert] = config[:ssl_cert]
      end

      if config[:ssl_ca_cert]
        ssl_opts[:ssl_ca_cert] = config[:ssl_ca_cert]
      end
    end

    mongo_client = MongoClient.new(host, port, ssl_opts)
    @db = mongo_client.db(db_name)
    @db.authenticate(db_user, db_password) unless db_user.nil?

    @is_master = { 'isMaster' => 1 }
    begin
      metrics = {}
      _result = @db.command(@is_master)['ok'] == 1
      server_status = @db.command('serverStatus' => 1)
      if server_status['ok'] == 1
        metrics.update(gather_replication_metrics(server_status))
        timestamp = Time.now.to_i
        metrics.each do |k, v|
          output [config[:scheme], k].join('.'), v, timestamp
        end
      end
      ok
    rescue
      exit(1)
    end
  end

  def gather_replication_metrics(server_status)
    server_metrics = {}
    server_metrics['lock.ratio'] = "#{sprintf('%.5f', server_status['globalLock']['ratio'])}" unless server_status['globalLock']['ratio'].nil?

    server_metrics['lock.queue.total'] = server_status['globalLock']['currentQueue']['total']
    server_metrics['lock.queue.readers'] = server_status['globalLock']['currentQueue']['readers']
    server_metrics['lock.queue.writers'] = server_status['globalLock']['currentQueue']['writers']

    server_metrics['connections.current'] = server_status['connections']['current']
    server_metrics['connections.available'] = server_status['connections']['available']

    if server_status['indexCounters']['btree'].nil?
      server_metrics['indexes.missRatio'] = "#{sprintf('%.5f', server_status['indexCounters']['missRatio'])}"
      server_metrics['indexes.hits'] = server_status['indexCounters']['hits']
      server_metrics['indexes.misses'] = server_status['indexCounters']['misses']
    else
      server_metrics['indexes.missRatio'] = "#{sprintf('%.5f', server_status['indexCounters']['btree']['missRatio'])}"
      server_metrics['indexes.hits'] = server_status['indexCounters']['btree']['hits']
      server_metrics['indexes.misses'] = server_status['indexCounters']['btree']['misses']
    end

    server_metrics['cursors.open'] = server_status['cursors']['totalOpen']
    server_metrics['cursors.timedOut'] = server_status['cursors']['timedOut']

    server_metrics['mem.residentMb'] = server_status['mem']['resident']
    server_metrics['mem.virtualMb'] = server_status['mem']['virtual']
    server_metrics['mem.mapped'] = server_status['mem']['mapped']
    server_metrics['mem.pageFaults'] = server_status['extra_info']['page_faults']

    server_metrics['asserts.warnings'] = server_status['asserts']['warning']
    server_metrics['asserts.errors'] = server_status['asserts']['msg']
    server_metrics
  end
end
