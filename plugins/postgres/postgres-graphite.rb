#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'pg'
require 'sensu-plugin/metric/cli'
require 'socket'

class CheckpostgresReplicationStatus < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
  :description => "Metric naming scheme, text to prepend to metric",
  :short => "-s SCHEME",
  :long => "--scheme SCHEME",
  :default => "#{Socket.gethostname}.postgresql_replication_lag"

  def run
    # Establishing connections to the master
    conn_master = PGconn.connect('@dbmaster',@dbport,'','','postgres',"@dbusername","@password")
    res1 = conn_master.exec('SELECT pg_current_xlog_location()').getvalue(0,0)
    m_segbytes = conn_master.exec( 'SHOW wal_segment_size' ).getvalue( 0, 0 ).sub( /\D+/, '' ).to_i << 20
    conn_master.close

    def lag_compute(res1,res,m_segbytes)
      m_segment, m_offset = res1.split( /\// )
      s_segment, s_offset = res.split( /\// )
      return (( m_segment.hex - s_segment.hex ) * m_segbytes) + ( m_offset.hex - s_offset.hex )
    end

    # Establishing connections to the slave
    conn_slave = PGconn.connect('@dbslave',@dbport,'','','postgres',"@dbusername","@password")
    res = conn_slave.exec('SELECT pg_last_xlog_receive_location()').getvalue(0,0)
    conn_slave.close

    # Computing for lag
    lag=lag_compute(res1,res,m_segbytes)
    lag_in_megs = ( lag.to_f / 1024 / 1024 ).abs

    message = "replication delayed by #{lag}"

    output "#{config[:scheme]}", lag

    ok
  end
end
