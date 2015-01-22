#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'pg'
require 'sensu-plugin/metric/cli'
require 'socket'

class CheckpostgresReplicationStatus < Sensu::Plugin::Metric::CLI::Graphite
  option :master_host,
         short: '-m',
         long: '--master=HOST',
         description: 'PostgreSQL master HOST'

  option :slave_host,
         short: '-s',
         long: '--slave=HOST',
         description: 'PostgreSQL slave HOST',
         default: 'localhost'

  option :database,
         short: '-d',
         long: '--database=NAME',
         description: 'Database NAME',
         default: 'postgres'

  option :user,
         short: '-u',
         long: '--username=VALUE',
         description: 'Database username'

  option :pass,
         short: '-p',
         long: '--password=VALUE',
         description: 'Database password'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-g SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.postgres.replication_lag"

  def run
    @dbmaster = config[:master_host]
    @dbslave = config[:slave_host]
    @dbport = 5432
    @dbname = config[:database]
    @dbusername = config[:user]
    @password = config[:pass]

    # Establishing connections to the master
    conn_master = PGconn.connect(@dbmaster, @dbport, '', '', @dbname, @dbusername, @password)
    res1 = conn_master.exec('SELECT pg_current_xlog_location()').getvalue(0, 0)
    m_segbytes = conn_master.exec('SHOW wal_segment_size').getvalue(0, 0).sub(/\D+/, '').to_i << 20
    conn_master.close

    def lag_compute(res1, res, m_segbytes)
      m_segment, m_offset = res1.split(/\//)
      s_segment, s_offset = res.split(/\//)
      ((m_segment.hex - s_segment.hex) * m_segbytes) + (m_offset.hex - s_offset.hex)
    end

    # Establishing connections to the slave
    conn_slave = PGconn.connect(@dbslave, @dbport, '', '', @dbname, @dbusername, @password)
    res = conn_slave.exec('SELECT pg_last_xlog_receive_location()').getvalue(0, 0)
    conn_slave.close

    # Compute lag
    lag = lag_compute(res1, res, m_segbytes)
    output "#{config[:scheme]}", lag

    ok
  end
end
