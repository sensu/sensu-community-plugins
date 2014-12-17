#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'pg'

class CheckPostgresReplicationStatus < Sensu::Plugin::Check::CLI
  option(:master_host,
         short: '-m',
         long: '--master-host=HOST',
         description: 'PostgreSQL master HOST')

  option(:slave_host,
         short: '-s',
         long: '--slave-host=HOST',
         description: 'PostgreSQL slave HOST',
         default: 'localhost')

  option(:database,
         short: '-d',
         long: '--database=NAME',
         description: 'Database NAME')

  option(:user,
         short: '-u',
         long: '--user=USER',
         description: 'Database USER')

  option(:password,
         short: '-p',
         long: '--password=PASSWORD',
         description: 'Database PASSWORD')

  option(:ssl,
         short: '-s',
         long: '--ssl',
         boolean: true,
         description: 'Require SSL')

  option(:warn,
         short: '-w',
         long: '--warning=VALUE',
         description: 'Warning threshold for replication lag (in MB)',
         default: 900,
         # #YELLOW
         proc: lambda { |s| s.to_i }) # rubocop:disable Lambda

  option(:crit,
         short: '-c',
         long: '--critical=VALUE',
         description: 'Critical threshold for replication lag (in MB)',
         default: 1800,
         # #YELLOW
         proc: lambda { |s| s.to_i }) # rubocop:disable Lambda

  def compute_lag(master, slave, m_segbytes)
    m_segment, m_offset = master.split('/')
    s_segment, s_offset = slave.split('/')
    ((m_segment.hex - s_segment.hex) * m_segbytes) + (m_offset.hex - s_offset.hex)
  end

  def run
    ssl_mode = config[:ssl] ? 'require' : 'prefer'

    # Establishing connection to the master
    conn_master = PG.connect(host: config[:master_host],
                             dbname: config[:database],
                             user: config[:user],
                             password: config[:password],
                             sslmode: ssl_mode)

    master = conn_master.exec('SELECT pg_current_xlog_location()').getvalue(0, 0)
    m_segbytes = conn_master.exec('SHOW wal_segment_size').getvalue(0, 0).sub(/\D+/, '').to_i << 20
    conn_master.close

    # Establishing connection to the slave
    conn_slave = PG.connect(host: config[:slave_host],
                            dbname: config[:database],
                            user: config[:user],
                            password: config[:password],
                            sslmode: ssl_mode)

    slave = conn_slave.exec('SELECT pg_last_xlog_receive_location()').getvalue(0, 0)
    conn_slave.close

    # Computing lag
    lag = compute_lag(master, slave, m_segbytes)
    lag_in_mb = (lag.to_f / 1024 / 1024).abs

    message = "replication delayed by #{lag_in_mb}MB :: master:#{master} slave:#{slave} m_segbytes:#{m_segbytes}"

    case
    when lag_in_mb >= config[:crit]
      critical message
    when lag_in_mb >= config[:warn]
      warning message
    else
      ok message
    end
  end
end
