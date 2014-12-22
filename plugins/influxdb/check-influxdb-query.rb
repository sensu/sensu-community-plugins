#! /usr/bin/env ruby
#
#   check-influxdb-query
#
# DESCRIPTION:
#   Check InfluxDB queries
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: jsonpath
#   gem: json
#   gem: dentaku
#
# USAGE:
#   example commands
#
# NOTES:
#   See the README here https://github.com/zeroXten/check_influxdb_query
#
# LICENSE:
#   Copyright 2014, Fraser Scott <fraser.scott@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'influxdb'
require 'sensu-plugin/check/cli'
require 'json'
require 'jsonpath'
require 'dentaku'

VERSION = '0.1.0'

class CheckInfluxdbQuery < Sensu::Plugin::Check::CLI
  check_name nil
  option :host,
         short: '-H HOST',
         long: '--host HOST',
         default: 'localhost',
         description: 'InfluxDB host'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         default: '8086',
         description: 'InfluxDB port'

  option :database,
         short: '-d DATABASE',
         long: '--database DATABASE',
         default: 'influxdb',
         description: 'InfluxDB database name'

  option :username,
         short: '-u USERNAME',
         long: '--username USERNAME',
         default: 'root',
         description: 'API username'

  option :password,
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         default: 'root',
         description: 'API password'

  option :query,
         short: '-q QUERY',
         long: '--query QUERY',
         required: true,
         description: 'Query to run. See http://influxdb.com/docs/v0.8/api/query_language.html'

  option :alias,
         short: '-a ALIAS',
         long: '--alias ALIAS',
         default: nil,
         description: 'Alias of query (e.g. if query and output gets too long)'

  option :jsonpath,
         short: '-j JSONPATH',
         long: '--jsonpath JSONPATH',
         default: nil,
         description: 'Json path to select value. Takes the first value, or 0 if none. See http://goessner.net/articles/JsonPath/'

  option :noresult,
         short: '-n',
         long: '--noresult',
         boolean: true,
         description: 'Go critical for no result from query'

  option :warning,
         short: '-w WARNING',
         long: '--warning WARNING',
         default: nil,
         description: "Warning threshold expression. E.g. 'value >= 10'. See https://github.com/rubysolo/dentaku"

  option :critical,
         short: '-c CRITICAL',
         long: '--critical CRITICAL',
         default: nil,
         description: "Critical threshold expression. E.g. 'value >= 20'. See https://github.com/rubysolo/dentaku"

  option :help,
         short: '-h',
         long: '--help',
         description: 'Show this message',
         on: :tail,
         boolean: true,
         show_options: true,
         exit: 0

  option :version,
         short: '-v',
         long: '--version',
         description: 'Show version',
         on: :tail,
         boolean: true,
         proc: proc { puts "Version #{VERSION}" },
         exit: 0

  def run
    influxdb = InfluxDB::Client.new config[:database],
                                    host: config[:host],
                                    port: config[:port],
                                    username: config[:username],
                                    password: config[:password]

    value = influxdb.query config[:query]

    if config[:alias]
      query_name = config[:alias]
    else
      query_name = config[:query]
    end

    if config[:noresult] && value.empty?
      critical "No result for query '#{query_name}'"
    end

    if config[:jsonpath]
      json_path = JsonPath.new(config[:jsonpath])
      value = json_path.on(value).first || 0

      calc = Dentaku::Calculator.new
      if config[:critical] && calc.evaluate(config[:critical], value: value)
        critical "Value '#{value}' matched '#{config[:critical]}' for query '#{query_name}'"
      elsif config[:warning] && calc.evaluate(config[:warning], value: value)
        warning "Value '#{value}' matched '#{config[:warning]}' for query '#{query_name}'"
      else
        ok "Value '#{value}' ok for query '#{query_name}'"
      end
    else
      puts 'Debug output. Use -j to check value...'
      puts JSON.pretty_generate(value)
    end
  end
end
