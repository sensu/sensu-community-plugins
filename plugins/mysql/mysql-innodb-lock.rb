#!/usr/bin/env ruby
#
# MySQL InnoDB Lock Check Plugin
# ===
#
# This plugin checks InnoDB locks.
#
# Copyright 2014 Hiroaki Sano <hiroaki.sano.9stories@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'mysql'

class CheckMySQLInnoDBLock < Sensu::Plugin::Check::CLI

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

  option :warn,
         :description => "Warning threshold",
         :short => '-w SECONDS',
         :long => '--warning SECONDS',
         :default => 5

  option :crit,
         :description => "Critical threshold",
         :short => '-c SECONDS',
         :long => '--critical SECONDS',
         :default => 10

  def run
    begin
      db = Mysql.new(config[:hostname], config[:user], config[:password], config[:database], config[:port].to_i, config[:socket])

      warn = config[:warn].to_i
      crit = config[:crit].to_i

      res = db.query <<-EQSQL
        select
          t_b.trx_mysql_thread_id blocking_id,
          t_w.trx_mysql_thread_id requesting_id,
          p_b.HOST blocking_host,
          p_w.HOST requesting_host,
          l.lock_table lock_table,
          l.lock_index lock_index,
          l.lock_mode lock_mode,
          p_w.TIME seconds,
          p_b.INFO blocking_info,
          p_w.INFO requesting_info
        from
          information_schema.INNODB_LOCK_WAITS w,
          information_schema.INNODB_LOCKS l,
          information_schema.INNODB_TRX t_b,
          information_schema.INNODB_TRX t_w,
          information_schema.PROCESSLIST p_b,
          information_schema.PROCESSLIST p_w
        where
            w.blocking_lock_id = l.lock_id
          and
            w.blocking_trx_id = t_b.trx_id
          and
            w.requesting_trx_id = t_w.trx_id
          and
            t_b.trx_mysql_thread_id = p_b.ID
          and
            t_w.trx_mysql_thread_id = p_w.ID
          and
            p_w.TIME > #{warn}
        order by
          requesting_id,blocking_id
      EQSQL

      lock_info = []
      is_crit = false
      res.each_hash do |row|
        h = {}
        if row['seconds'].to_i > crit
          is_crit = true
        end
        h['blocking_id'] = row['blocking_id']
        h['requesting_id'] = row['requesting_id']
        h['blocking_host'] = row['blocking_host']
        h['requesting_host'] = row['requesting_host']
        h['lock_table'] = row['lock_table']
        h['lock_index'] = row['lock_index']
        h['lock_mode'] = row['lock_mode']
        h['seconds'] = row['seconds']
        h['blocking_info'] = row['blocking_info']
        h['requesting_info'] = row['requesting_info']
        lock_info.push(h)
      end

      if lock_info.length == 0
        ok
      elsif is_crit == false
        warning "Detected Locks #{lock_info}"
      else
        critical "Detected Locks #{lock_info}"
      end

    rescue Mysql::Error => e
      critical "MySQL check failed: #{e.error}"
    ensure
      db.close if db
    end
  end
end
