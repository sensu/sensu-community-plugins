#! /usr/bin/env ruby
#
#   <script name>
#
# DESCRIPTION:
#   This plugin checks the status of processes
#   managed with Eye via the HTTP API provided by the
#   'eye-http' gem (github.com/kostya/eye-http)
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Nate Meyer <nmeyer@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'json'

class CheckEyeHttp < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h host',
         default: '127.0.0.1'

  option :port,
         short: '-p port',
         default: 12_345

  option :uri,
         short: '-u uri',
         default: '/api/info?filter=all'

  option :debug,
         short: '-d'

  def run
    out = { ok: [], warn: [], crit: [] }

    status_doc = JSON.parse(eye_status)['result']['subtree']

    status_doc.each do |app|
      app['subtree'].each do |group|
        group['subtree'].each do |process|
          proc_summary = string_formatter app['name'],
                                          group['name'],
                                          process['name'],
                                          process['state']

          puts debug(proc_summary) if config[:debug]

          case process['state']
          when 'up'
            out[:ok] << proc_summary
          when 'starting', 'stopping', 'restarting'
            out[:warn] << proc_summary
          when 'unmonitored', 'down'
            out[:crit] << proc_summary
          else
            puts process['state'] if config[:debug]
          end
        end
      end
    end
    process_statuses out
  end

  private

  def debug(s)
    "DEBUG: #{s}"
  end

  def string_formatter(app, group, process, state)
    "#{state.upcase}: #{app}::#{group}::#{process}"
  end

  def process_statuses(out)
    if out[:crit].any?
      critical "\n\t#{out[:crit].join("\n\t")}"
    elsif out[:warn].any?
      warning "\n\t#{out[:warn].join("\n\t")}"
    elsif out[:ok].any?
      ok "\nAll applications OK.\n\t#{out[:ok].join("\n\t")}"
    end
  end

  def eye_status
    res = Net::HTTP.start(config[:host], config[:port]) do |http|
      req = Net::HTTP::Get.new(config[:uri])
      http.request(req)
    end

    unless res.code.to_i == 200
      unknown "Failed to fetch status from #{config[:host]}:#{config[:port]}"
    end

    res.body
  end
end
