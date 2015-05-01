#! /usr/bin/env ruby
#
#   nginx-response-metrics
#
# DESCRIPTION:
#   Pull nginx metrics for backends using access logs
#   - count per HTTP status
#   - count per NGINX cache status
#   - total unique ips
#   - top 5 counts per ip
#   per domain
#
#   Requires domain to bin in access logs, not just path
#   - "$request_method $scheme://$host$request_uri $server_protocol"
#   Requires upstream cache to be in the access logs as last field
#   - $upstream_cache_status
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: socket
#   gem: uri
#   gem: open3
#   logsince - log utility that returns from last call, source: https://github.com/himyouten/logsince-go
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 himyouten@gmail.com <himyouten@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'socket'
require 'uri'
require 'open3'

class NginxMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :log,
         short: '-l LOG',
         long: '--log LOG',
         description: 'Path to access log',
         default: '/var/log/nginx/access.log'

  option :logsince,
         short: '-b LOGSINCE',
         long: '--logsince LOGSINCE',
         description: 'Path to logsince binary',
         default: '/usr/local/sbin/logsince'

  option :hostname,
         short: '-h HOST[,HOST,..]',
         long: '--host HOST[,HOST,..]',
         description: 'Hostnames to filter on',
         default: ''

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.nginx_response"

  def clean_string(str)
    str.gsub /[\. ]/, "_"
  end

  def get_host(url)
    host = URI.parse(url).host.downcase
  end

  def run
    found = false
    attempts = 0
    response_code_totals = Hash.new
    cache_code_totals = Hash.new
    ip_totals = Hash.new
    until found || attempts >= 3
      attempts += 1
      # get the output from logsince|awk
      stdout, stderr, status = Open3.capture3(config[:logsince], config[:log] )
      if status.exitstatus > 0
        # print error message
        unknown "error executing logsince:%s" % stderr
      else
        found = 0
        filter_hostname = false
        if config[:hostname].length > 0
          filter_hostname = true
          hostnames = config[:hostname].split(/,/)
        end

        # parse and build per hostname
        stdout.each_line do |line|
          fields = line.split(/ /)

          # get the host
          host = get_host(fields[6])

          # if hostnames provided only use those
          next if filter_hostname && (hostnames.include? host)

          # increment the counters
          field = fields[0]
          ip_totals[host] = Hash.new unless ip_totals.key?(host)
          if ip_totals[host].key?(field)
            ip_totals[host][field] += 1
          else
            ip_totals[host][field] = 1
          end

          field = fields[-1]
          field.chomp!
          if field == '-'
            field = 'NA'
          end
          cache_code_totals[host] = Hash.new unless cache_code_totals.key?(host)
          if cache_code_totals[host].key?(field)
            cache_code_totals[host][field] += 1
          else
            cache_code_totals[host][field] = 1
          end

          field = fields[8]
          response_code_totals[host] = Hash.new unless response_code_totals.key?(host)
          if response_code_totals[host].key?(field)
            response_code_totals[host][field] += 1
          else
            response_code_totals[host][field] = 1
          end

        end
      end
    end # until

    # #YELLOW
    # response codes output
    if response_code_totals.length > 0
      response_code_totals.map do |domain, by_domain|
        domain = clean_string(domain)
        by_domain.map do |code, total|
          output "#{config[:scheme]}.#{domain}.responsecode.#{code}", total
        end
      end
    end
    # cache codes output
    if cache_code_totals.length > 0
      cache_code_totals.map do |domain, by_domain|
        domain = clean_string(domain)
        by_domain.map do |code, total|
          output "#{config[:scheme]}.#{domain}.cachecode.#{code}", total
        end
      end
    end

    # ips
    if ip_totals.length > 0
      ip_totals.map do |domain, by_domain|
        domain = clean_string(domain)
        output "#{config[:scheme]}.#{domain}.unique_ips", by_domain.length
        by_domain.sort_by{ |k,v| v }.reverse.take(5).each_with_index do |total, index|
          output "#{config[:scheme]}.#{domain}.top_ips.#{index}", total[1]
        end
      end
    end

    ok
  end
end
