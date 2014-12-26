#!/usr/bin/env ruby

require 'rubygems'
require 'sensu-handler'
require 'influxdb'

class SensuToInfluxDB < Sensu::Handler
  def filter; end

  def handle
    influxdb_server = settings['influxdb']['server']
    influxdb_port   = settings['influxdb']['port']
    influxdb_user   = settings['influxdb']['username']
    influxdb_pass   = settings['influxdb']['password']
    influxdb_db     = settings['influxdb']['database']

    influxdb_data = InfluxDB::Client.new influxdb_db, host: influxdb_server,
                                                      username: influxdb_user,
                                                      password: influxdb_pass,
                                                      port: influxdb_port,
                                                      server: influxdb_server
    mydata = []
    @event['check']['output'].each do |metric|
      m = metric.split
      next unless m.count == 3
      key = m[0].split('.', 2)[1]
      key.gsub!('.', '_')
      value = m[1].to_f
      mydata = { host: @event['client']['name'], value: value,
                 ip: @event['client']['address']
               }
      influxdb_data.write_point(key, mydata)
    end
  end
end
