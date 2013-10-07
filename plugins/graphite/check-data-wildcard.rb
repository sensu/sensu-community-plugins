#!/usr/bin/env ruby
#
# Check graphite values
# ===
#
# This plugin checks values within graphite

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'open-uri'

class CheckGraphiteData < Sensu::Plugin::Check::CLI

  option :target,
    :description => 'Graphite data target',
    :short => '-t TARGET',
    :long => '--target TARGET',
    :required => true

  option :server,
    :description => 'Server host and port',
    :short => '-s SERVER:PORT',
    :long => '--server SERVER:PORT',
    :required => true

  option :warning,
    :description => 'Generate warning if given value is above received value',
    :short => '-w VALUE',
    :long => '--warn VALUE',
    :proc => proc{|arg| arg.to_f }

  option :critical,
    :description => 'Generate critical if given value is above received value',
    :short => '-c VALUE',
    :long => '--critical VALUE',
    :proc => proc{|arg| arg.to_f }

  option :reset_on_decrease,
    :description => 'Send OK if value has decreased on any values within END-INTERVAL to END',
    :short => '-r INTERVAL',
    :long => '--reset INTERVAL',
    :proc => proc{|arg| arg.to_i }

  option :name,
    :description => 'Name used in responses',
    :short => '-n NAME',
    :long => '--name NAME',
    :default => "graphite check"

  option :allowed_graphite_age,
    :description => 'Allowed number of seconds since last data update (default: 60 seconds)',
    :short => '-a SECONDS',
    :long => '--age SECONDS',
    :default => 60,
    :proc => proc{|arg| arg.to_i }

  option :hostname_sub,
    :description => 'Character used to replace periods (.) in hostname (default: _)',
    :short => '-s CHARACTER',
    :long => '--host-sub CHARACTER'

  option :from,
    :description => 'Get samples starting from FROM (default: -10mins)',
    :short => '-f FROM',
    :long => '--from FROM',
    :default => "-10mins"

  option :help,
    :description => 'Show this message',
    :short => '-h',
    :long => '--help'

  # Run checks
  def run
    if config[:help]
      puts opt_parser if config[:help]
      exit
    end
   
    data = retreive_data
    data.each_pair do |key,value|
      check_age(value) || check(value,:critical) || check(value,:warning)
    end
    ok("#{name} values OK")
  end

  # name used in responses
  def name
    base = config[:name]
    @formatted ? "#{base} (#{@formatted})" : base
  end

  # Check the age of the data being processed
  def check_age(value)
    if((Time.now.to_i - value['end']) > config[:allowed_graphite_age])
      unknown "Graphite data age is past allowed threshold (#{config[:allowed_graphite_age]} seconds)"
    end
  end

  # grab data from graphite
  def retreive_data
    unless(@raw_data)
      begin
        handle = open("http://#{config[:server]}/render?format=json&target=#{formatted_target}&from=#{config[:from]}")
        output = {}
        rawdata = JSON.parse(handle.gets)
        rawdata.each do |raw|
          raw['datapoints'].delete_if{|v| v.first == nil}
          next if raw['datapoints'].empty?
          target = raw['target']
          data = raw['datapoints'].map(&:first)
          start = raw['datapoints'].first.last
          dend = raw['datapoints'].last.last
          step = ((dend - start) / raw['datapoints'].size.to_f).ceil
          output[target] = { 'target' => target, 'data' => data, 'start' => start, 'end' => dend, 'step' => step }
        end
        output
      rescue OpenURI::HTTPError
        critical "Failed to connect to graphite server"
      rescue NoMethodError
        critical "No data for time period and/or target"
      end
    end
  end

  # type:: :warning or :critical
  # Return alert if required
  def check(value,type)
    if(config[type])
      if(value['data'].last > config[type] && !decreased?)
        send(type, "#{value['target']} has passed #{type} threshold of #{config[type].to_i}")
      end
    end
  end

  # Check if values have decreased within interval if given
  def decreased?
    if(config[:reset_on_decrease])
      slice = @data.slice(@data.size - config[:reset_on_decrease], @data.size)
      val = slice.shift until slice.empty? || val.to_f > slice.first
      !slice.empty?
    else
      false
    end
  end

  # Returns formatted target with hostname replacing any $ characters
  def formatted_target
    if(config[:target].include?('$'))
      require 'socket'
      @formatted = Socket.gethostbyname(Socket.gethostname).first.gsub('.', config[:hostname_sub] || '_')
      config[:target].gsub('$', @formatted)
    else
      config[:target]
    end
  end

end
