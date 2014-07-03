#!/usr/bin/env ruby
#
# Checks etcd node self stats
# ===
#
# DESCRIPTION:
#   This plugin checks that the stats/self url returns 200OK
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   rest-client Ruby gem
#
# this is a first pass need to figure out all bad responses
# 
# AUTHOR:
#   Will Salt - williamejsalt@gmail.com
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class EtcdNodeStatus < Sensu::Plugin::Check::CLI

  option :server,
    :description => 'etcd server',
    :short => '-s SERVER',
    :long => '--server SERVER',
    :default => 'localhost'

  def get_es_resource(resource)
    begin
      r = RestClient::Resource.new("http://#{config[:server]}:4001/#{resource}", :timeout => 5)
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    end
  end

  def run
    begin
      r = RestClient::Resource.new("http://#{config[:server]}:4001/v2/stats/self", :timeout => 5)
      JSON.parse(r.get)
      ok "etcd is up"
    rescue Errno::ECONNREFUSED
      critical "Etcd is not responding"
    rescue RestClient::RequestTimeout
      critical 'Etcd Connection timed out'
    end
  end
end
