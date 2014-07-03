#!/usr/bin/env ruby
#
# Get OpenStack Keystone token counts from MySQL
# ===
#
# Dependencies:
#  - mysql2 gem
#
# Query MySQL for Keystone token counts and output in graphite-friendly
# format. Shows active, expired, and total token counts. Also has the
# option to produce counts by individual Keystone username (--by-user)
# as well as a filtered list of username(s) (--ks-users).
#
# Copyright 2013 Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'mysql2'
require 'socket'

class KeystoneTokenCounts < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
         :short => '-h HOST',
         :long => '--host HOST',
         :description => 'Mysql Host to connect to',
         :default => 'localhost'

  option :port,
         :short => '-P PORT',
         :long => '--port PORT',
         :description => 'Mysql Port to connect to',
         :proc => proc { |p| p.to_i },
         :default => 3306

  option :username,
         :short => '-u USERNAME',
         :long => '--user USERNAME',
         :description => 'Mysql Username',
         :required => true

  option :password,
         :short => '-p PASSWORD',
         :long => '--pass PASSWORD',
         :description => 'Mysql password',
         :default => ''

  option :scheme,
         :description => 'Metric naming scheme, text to prepend to metric',
         :short => '-s SCHEME',
         :long => '--scheme SCHEME',
         :default => "#{Socket.gethostname}.keystone.tokens"

  option :socket,
         :short => '-S SOCKET',
         :long => '--socket SOCKET'

  option :by_user,
         :description => 'Show token counts by user',
         :long => '--by-user',
         :boolean => true,
         :default => false

  option :ks_users,
         :description => 'Delimited list of users to include',
         :long => '--ks-users USER[,USER]'

  option :database,
         :short => '-d DATABASE',
         :long => '--database DATABASE',
         :description => 'Database name',
         :default => 'keystone'

  def run
    if config[:ks_users]
      config[:by_user] = true
      where = "WHERE user.name IN ('#{config[:ks_users].gsub(/,/, "', '")}')"
    end
    metrics = %w(active expired total)
    sql = <<-eosql
SELECT #{ 'user.name,' if config[:by_user] }
  SUM(IF(NOW() <= expires,1,0)) AS active,
  SUM(IF(NOW() > expires,1,0)) AS expired,
COUNT(*) AS total FROM token
    eosql
    sql.concat <<-eosql if config[:by_user]
LEFT JOIN user ON token.user_id = user.id #{ where }
GROUP BY user.name
    eosql
    begin
      mysql = Mysql2::Client.new(
        :host => config[:host], :port => config[:port],
        :username => config[:username], :password => config[:password],
        :socket => config[:socket], :database => config[:database]
      )
      mysql.query(sql).each do |row|
        metrics.size.times do |i|
          if config[:by_user]
            output "#{config[:scheme]}.#{row['name']}.#{metrics[i]}",
                   row[metrics[i]]
          else
            output "#{config[:scheme]}.#{metrics[i]}", row[metrics[i]]
          end
        end
      end
    rescue => e
      puts e.message
    ensure
      mysql.close if mysql
    end
    ok
  end

end
