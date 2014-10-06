#!/usr/bin/env ruby

#
# Checks metrics in graphite, averaged over a period of time.
#
# The fired sensu event will only be critical if a stat is
# above the critical threshold. Otherwise, the event will be warning,
# if a stat is above the warning threshold.
#
# Multiple stats will be checked if * are used
# in the "target" query.
#
# Author: Alan Smith (alan@asmith.me)
# Date: 08/28/2014
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'json'
require 'net/http'
require 'sensu-plugin/check/cli'

class CheckGraphiteStat < Sensu::Plugin::Check::CLI

  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "graphite hostname",
    :proc => proc {|p| p.to_s },
    :default => "graphite"

  option :period,
    :short => "-p PERIOD",
    :long => "--period PERIOD",
    :description => "The period back in time to extract from Graphite. Use -24hours, -2days, -15mins, etc, same format as in Graphite",
    :proc => proc {|p| p.to_s },
    :required => true

  option :target,
    :short => "-t TARGET",
    :long => "--target TARGET",
    :description => "The graphite metric name. Can include * to query multiple metrics",
    :proc => proc {|p| p.to_s },
    :required => true

  option :warn,
    :short => "-w WARN",
    :long => "--warn WARN",
    :description => "Warning level",
    :proc => proc {|p| p.to_f },
    :required => false

  option :crit,
    :short => "-c Crit",
    :long => "--crit CRIT",
    :description => "Critical level",
    :proc => proc {|p| p.to_f },
    :required => false

  def average(a)
    total = 0
    a.to_a.each {|i| total += i.to_f}

    total / a.length
  end

  def danger(metric)
    datapoints = metric['datapoints'].collect {|p| p[0].to_f}

    unless datapoints.empty?
      avg = average(datapoints)

      if !config[:crit].nil? && avg > config[:crit]
        return [2, "#{metric['target']} is #{avg}"]
      elsif !config[:warn].nil? && avg > config[:warn]
        return [1, "#{metric['target']} is #{avg}"]
      end
    end
    [0, nil]
  end

  def run
    body =
      begin
        uri = URI("http://#{config[:host]}/render?format=json&target=#{config[:target]}&from=#{config[:period]}")
        res = Net::HTTP.get_response(uri)
        res.body
      rescue Exception => e
        warning "Failed to query graphite: #{e.inspect}"
      end

    status = 0
    message = ''
    data =
      begin
        JSON.parse(body)
      rescue
        []
      end

    unknown "No data from graphite" if data.empty?

    data.each do |metric|
      s, msg = danger(metric)

      message += "#{msg} " unless s == 0
      status = s unless s < status
    end

    if status == 2
      critical message
    elsif status == 1
      warning message
    end
    ok
  end
end
