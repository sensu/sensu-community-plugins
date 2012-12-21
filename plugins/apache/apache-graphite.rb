#!/usr/bin/env ruby
#
# Apache metrics based on mod_status
# ===
#
# DESCRIPTION:
#   This plugin retrives machine-readable output of mod_status, parse
#   it, and generates apache process metrics formated for Graphite.
#
# OUTPUT:
#   Graphite plain-text format (name value timestamp\n)
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   Apache mod_status module
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/http'

class ApacheMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "HOST to check mod_status output",
    :default => "localhost"

  option :port,
    :short => "-p PORT",
    :long => "--port PORT",
    :description => "Port to check mod_status output",
    :default => "80"

  option :path,
    :short => "-path PATH",
    :long => "--path PATH",
    :description => "PATH to check mod_status output",
    :default => "/server-status?auto"

  option :user,
    :short => "-user USER",
    :long => "--user USER",
    :description => "User if HTTP Basic is used"

  option :password,
    :short => "-password USER",
    :long => "--password USER",
    :description => "Password if HTTP Basic is used"

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  def get_mod_status
    http = Net::HTTP.new(config[:host], config[:port])
    req = Net::HTTP::Get.new(config[:path])
    if (config[:user] != nil and config[:password] != nil)
      req.basic_auth config[:user], config[:password]
    end
    res = http.request(req)
    case res.code
    when "200"
      res.body
    else
      critical "Unable to get Apache metrics, unexpected HTTP response code: #{res.code}"
    end
  end

  def run
    timestamp = Time.now.to_i
    stats = Hash.new
    get_mod_status.split("\n").each do |line|
      name, value = line.split(": ")
      case name
      when "ReqPerSec"
        stats["requests_per_sec"] = value.to_i
      when "BytesPerSec"
        stats["kbytes_per_sec"] = (value.to_i/1024).to_i
      when "Scoreboard"
        value = value.strip
        stats["open"] = value.count(".")
        stats["waiting"] = value.count("_")
        stats["starting"] = value.count("S")
        stats["reading"] = value.count("R")
        stats["sending"] = value.count("W")
        stats["keepalive"] = value.count("K")
        stats["dnslookup"] = value.count("D")
        stats["closing"] = value.count("C")
        stats["logging"] = value.count("L")
        stats["finishing"] = value.count("G")
        stats["idle_cleanup"] = value.count("I")
        stats["total"] = value.length
      end
    end
    metrics = {
      :apache => stats
    }
    metrics.each do |parent, children|
      children.each do |child, value|
        output [config[:scheme], parent, child].join("."), value, timestamp
      end
    end
    ok
  end

end
