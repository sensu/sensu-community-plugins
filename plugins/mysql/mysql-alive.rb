#!/usr/bin/env ruby
#
# MySQL Alive Plugin
# ===
#
# This plugin attempts to login to mysql with provided credentials.
#
# Copyright 2011 Joe Crim <josephcrim@gmail.com>
# Updated by Lewis Preson 2012 to accept a database parameter
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'mysql'

class CheckMySQL < Sensu::Plugin::Check::CLI

  option :user,
         :description => "MySQL User",
         :short => '-u USER',
         :long => '--user USER'

  option :password,
         :description => "MySQL Password",
         :short => '-p PASS',
         :long => '--password PASS'

  option :hostname,
         :description => "Hostname to login to",
         :short => '-h HOST',
         :long => '--hostname HOST'

  option :database,
         :description => "Database schema to connect to",
         :short => '-d DATABASE',
         :long => '--database DATABASE',
         :default => "test"

  option :port,
         :description => "Port to connect to",
         :short => '-P PORT',
         :long => '--port PORT',
         :default => "3306"

  option :socket,
         :description => "Socket to use",
         :short => '-s SOCKET',
         :long => '--socket SOCKET'

  def run
    begin
      db = Mysql.real_connect(config[:hostname], config[:user], config[:password], config[:database], config[:port].to_i, config[:socket])
      info = db.get_server_info
      ok "Server version: #{info}"
    rescue Mysql::Error => e
      critical "Error message: #{e.error}"
    ensure
      db.close if db
    end
  end

end
