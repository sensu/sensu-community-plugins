#!/usr/bin/env ruby
#
# Copyright 2014 Paulo Miguel Almeida Rodenas (paulo.ubuntu@gmail.com)
#
# Depends on mysql gem
# gem install mysql
#
# This handler sends metrics to a MySQL database for later user such as
# historic comparisons, charts and so on
#
# =========== Initial DDL ===========
# MySQL initial can be found in mysql-metrics.sql
#
# =========== Config ===========
# MySQL 'hostname', 'username', and 'password' must be
# specified in a config file in /etc/sensu/conf.d.
# See mysql-metrics.json for an example.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'json'
require 'mysql'

class MysqlMetric < Sensu::Handler
  # override filters from Sensu::Handler. not appropriate for metric handlers
  def filter; end

  def handle
    # mysql settings
    mysql_hostname = settings['mysql']['hostname']
    mysql_username = settings['mysql']['username']
    mysql_password = settings['mysql']['password']

    # event values
    client_id = @event['client']['name']
    check_name = @event['check']['name']
    check_issued = @event['check']['issued']
    check_output = @event['check']['output']
    check_status = @event['check']['status']

    begin
      con = Mysql.new mysql_hostname, mysql_username, mysql_password
      con.query("INSERT INTO "\
                "sensumetrics.sensu_historic_metrics("\
                "client_id, check_name, issue_time, "\
                "output, status) "\
                "VALUES ('#{client_id}', '#{check_name}', "\
                "#{check_issued}, '#{check_output}', #{check_status})")
    rescue Mysql::Error => e
      puts e.errno
      puts e.error
    ensure
      con.close if con
    end
  end
end
