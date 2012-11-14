#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'pg'

class CheckpostgresReplicationStatus < Sensu::Plugin::Check::CLI

  option :warn,
    :short => '-w',
    :long => '--warning=VALUE',
    :description => 'Warning threshold for replication lag',
    :default => 900,
    :proc => lambda { |s| s.to_i }

  option :crit,
    :short => '-c',
    :long => '--critical=VALUE',
    :description => 'Critical threshold for replication lag',
    :default => 1800,
    :proc => lambda { |s| s.to_i }


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

    if lag_in_megs > config[:warn] and
      lag_in_megs <= config[:crit]
      warn message
    elsif lag_in_megs >= config[:crit]
      critical message
    else
      ok "slave: #{message}"
    end

  end
end
