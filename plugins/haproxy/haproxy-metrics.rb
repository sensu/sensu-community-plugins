#!/usr/bin/env ruby
#
# Pull haproxy metrics for backends
# ===
#
# Created by Pete Shima - me@peteshima.com
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# TODO: backend pool single node stats.
#

require "rubygems" if RUBY_VERSION < "1.9.0"
require 'sensu-plugin/metric/cli'
require "net/http"
require "net/https"
require "socket"
require "csv"


class HAProxyMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :hostname,
    :short => "-h HOSTNAME",
    :long => "--host HOSTNAME",
    :description => "HAproxy web stats hostname",
    :required => true

  option :path,
    :short => "-q STATUSPATH",
    :long => "--statspath STATUSPATH",
    :description => "HAproxy web stats path",
    :required => true

  option :username,
    :short => "-u USERNAME",
    :long => "--user USERNAME",
    :description => "HAproxy web stats username",
    :required => true

  option :password,
    :short => "-p PASSWORD",
    :long => "--pass PASSWORD",
    :description => "HAproxy web stats password",
    :required => true

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"


  def run

    res = Net::HTTP.start(config[:hostname], "80") do |http|
      req = Net::HTTP::Get.new("/#{config[:path]};csv;norefresh")
      req.basic_auth config[:username], config[:password]
      http.request(req)
    end

    output = {}
    parsed = CSV.parse(res.body)
    parsed.shift
    parsed.each do |line|
      next if line[1] != 'BACKEND'
      output "#{config[:scheme]}.haproxy.#{line[0]}.sessioncurrent", line[4]
      output "#{config[:scheme]}.haproxy.#{line[0]}.sessiontotal", line[7]
      output "#{config[:scheme]}.haproxy.#{line[0]}.bytesin", line[8]
      output "#{config[:scheme]}.haproxy.#{line[0]}.bytesout", line[9]
    end

    ok


  end

end
