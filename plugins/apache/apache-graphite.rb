#! /usr/bin/env ruby
# encoding: UTF-8
#
# apache-graphite
#
# DESCRIPTION:
#   This plugin retrieves machine-readable output of mod_status, parses
#   it, and generates Apache process metrics formatted for Graphite.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   Apache module: mod_status
#
# USAGE:
#  #YELLOW
#
# NOTES:
#   enable extended mod_status
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'net/https'

class ApacheMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'HOST to check mod_status output',
         default: 'localhost'

  option :port,
         short: '-p PORT',
         long: '--port PORT',
         description: 'Port to check mod_status output',
         default: '80'

  option :path,
         short: '-path PATH',
         long: '--path PATH',
         description: 'PATH to check mod_status output',
         default: '/server-status?auto'

  option :user,
         short: '-user USER',
         long: '--user USER',
         description: 'User if HTTP Basic is used'

  option :password,
         short: '-password USER',
         long: '--password USER',
         description: 'Password if HTTP Basic is used'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to .$parent.$child',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}"

  option :secure,
         short: '-s',
         long: '--secure',
         description: 'Use SSL'

  def acquire_mod_status
    http = Net::HTTP.new(config[:host], config[:port])
    if config[:secure]
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.use_ssl = true
    end
    req = Net::HTTP::Get.new(config[:path])
    if !config[:user].nil? && !config[:password].nil?
      req.basic_auth config[:user], config[:password]
    end
    res = http.request(req)
    case res.code
    when '200'
      res.body
    else
      critical "Unable to get Apache metrics, unexpected HTTP response code: #{res.code}"
    end
  end

  def run
    timestamp = Time.now.to_i
    stats = {}
    acquire_mod_status.split("\n").each do |line|
      name, value = line.split(': ')
      case name
      when 'Total Accesses'
        stats['total_accesses'] = value.to_i
      when 'Total kBytes'
        stats['total_bytes'] = (value.to_f * 1024).to_i
      when 'CPULoad'
        stats['cpuload'] = value.to_f * 100
      when 'BusyWorkers'
        stats['busy_workers'] = value.to_i
      when 'IdleWorkers'
        stats['idle_workers'] = value.to_i
      when 'ReqPerSec'
        stats['requests_per_sec'] = value.to_f
      when 'BytesPerSec'
        stats['bytes_per_sec'] = value.to_f
      when 'BytesPerReq'
        stats['bytes_per_req'] = value.to_f
      when 'Scoreboard'
        value = value.strip
        stats['open'] = value.count('.')
        stats['waiting'] = value.count('_')
        stats['starting'] = value.count('S')
        stats['reading'] = value.count('R')
        stats['sending'] = value.count('W')
        stats['keepalive'] = value.count('K')
        stats['dnslookup'] = value.count('D')
        stats['closing'] = value.count('C')
        stats['logging'] = value.count('L')
        stats['finishing'] = value.count('G')
        stats['idle_cleanup'] = value.count('I')
        stats['total'] = value.length
      end
    end
    metrics = {
      apache: stats
    }
    metrics.each do |parent, children|
      children.each do |child, value|
        output [config[:scheme], parent, child].join('.'), value, timestamp
      end
    end
    ok
  end
end
