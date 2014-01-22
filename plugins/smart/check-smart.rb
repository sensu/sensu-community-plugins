#!/usr/bin/env ruby
#
# Checks devices SMART attributes with smartmontool
# ===
#
# DESCRIPTION:
# S.M.A.R.T. - Self-Monitoring, Analysis and Reporting Technology
#
# Check hdd and ssd SMART attributes defined in smart.json file. Default is
# to check all attributes defined in this file if attribute is presented by hdd.
# If attribute not presented script will skip it.
#
# I defined smart.json file based on this two specification
# http://en.wikipedia.org/wiki/S.M.A.R.T.#cite_note-kingston1-32
# http://media.kingston.com/support/downloads/MKP_306_SMART_attribute.pdf
#
# I tested on several Seagate, WesternDigital hdd and Cosair force Gt SSD
#
# It is possible some hdd give strange attribute values and warnings based on it
# but in this case simply define attribute list with '-a' parameter
# and ignore wrong parameters. Maybe attribute 1 and 201 will be wrong because
# format of this attributes specified by hdd vendors.
#
# You can test the script just make a copy of your smartctl output and change some
# value. I put a hdd attribute file into 'test_hdd.txt' and a failed hdd file into
# 'test_hdd_failed.txt'.
#
# PLEASE TEST IT BEFORE YOU TRUST BLINDLY IN THIS SCRIPT!
#
# PLATFORMS:
#   linux
#
# DEPENDENCIES: json, smartmontools, smart.json file, suduers
#
# USAGE:
# You need to add 'sensu' user to suduers or you can't use 'smartctl'
# sensu   ALL=(ALL) NOPASSWD:ALL
#
# PARAMETERS:
# -b: smartctl binary to use, in case you hide yours (default: /usr/sbin/smartctl)
# -d: default threshold for crit_min,warn_min,warn_max,crit_max (default: 0,0,0,0)
# -a: SMART attributes to check (default: all)
# -t: Custom threshold for SMART attributes. (id,crit_min,warn_min,warn_max,crit_max)
# -o: Overall SMART health check (default: on)
# -d: Devices to check (default: all)
# --debug: turn debug output on (default: off)
# --debug_file: process this file instead of smartctl output for testing
#
# Copyright 2013 Peter Kepes <https://github.com/kepes>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'

class SmartCheck < Sensu::Plugin::Check::CLI
  option :binary,
    :short => "-b path/to/smartctl",
    :long => "--binary /usr/sbin/smartctl",
    :description => "smartctl binary to use, in case you hide yours",
    :required => false,
    :default => 'smartctl'

  option :defaults,
    :short => "-d 0,0,0,0",
    :long => "--defaults 0,0,0,0",
    :description => "default threshold for crit_min,warn_min,warn_max,crit_max",
    :required => false,
    :default => '0,0,0,0'

  option :attributes,
    :short => "-a 1,5,9,230",
    :long => "--attributes 1,5,9,230",
    :description => "SMART attributes to check",
    :required => false,
    :default => 'all'

  option :threshold,
    :short => "-t 194,5,10,50,60",
    :long => "--threshold 194,5,10,50,60",
    :description => "Custom threshold for SMART attributes. (id,crit_min,warn_min,warn_max,crit_max)",
    :required => false

  option :overall,
    :short => "-o off",
    :long => "--overall off",
    :description => "Overall SMART health check",
    :required => false,
    :default => 'on'

  option :devices,
    :short => "-d sda,sdb,sdc",
    :long => "--device sda,sdb,sdc",
    :description => "Devices to check",
    :required => false,
    :default => 'all'

  option :debug,
    :long => "--debug on",
    :description => "Turn debug output on",
    :required => false,
    :default => 'off'

  option :debug_file,
    :long => "--debugfile test_hdd.txt",
    :description => "Process a debug file for testing",
    :required => false

  def run
    @smartAttributes = JSON.parse(IO.read(File.dirname(__FILE__) + '/smart.json'), symbolize_names: true)[:smart][:attributes]
    @smartDebug = config[:debug] == 'on'

    # Set default threshold
    defaultThreshold = config[:defaults].split(',')
    raise 'Invalid default threshold parameter count' unless defaultThreshold.size == 4
    @smartAttributes.each do |att|
      att[:crit_min] = defaultThreshold[0].to_i if att[:crit_min].nil?
      att[:warn_min] = defaultThreshold[1].to_i if att[:warn_min].nil?
      att[:warn_max] = defaultThreshold[2].to_i if att[:warn_max].nil?
      att[:crit_max] = defaultThreshold[3].to_i if att[:crit_max].nil?
    end

    # Check threshold parameter if present
    unless config[:threshold].nil?
      thresholds = config[:threshold].split(',')
      # Check threshold parameter length
      raise 'Invalid threshold parameter count' unless thresholds.size % 5 == 0

      (0..(thresholds.size/5-1)).each do |i|
        att_id = @smartAttributes.index{|att| att[:id] == thresholds[i+0].to_i}
        thash = {crit_min: thresholds[i+1].to_i, warn_min: thresholds[i+2].to_i,
          warn_max: thresholds[i+3].to_i, crit_max: thresholds[i+4].to_i }
        @smartAttributes[att_id].merge! thash
      end
    end

    # Attributes to check
    attCheckList = findAttributes

    # Devices to check
    devices = config[:debug_file].nil? ? findDevices : ['sda']

    # Overall health and attributes parameter
    parameters = "-H -A"

    # Get attributes in raw48 format
    attCheckList.each do |att|
      parameters += " -v #{att},raw48"
    end

    output = {}
    warnings = []
    criticals = []
    devices.each do |dev|
      puts "#{config[:binary]} #{parameters} /dev/#{dev}" if @smartDebug
      # check if debug file specified
      if config[:debug_file].nil?
        output[dev] = `sudo #{config[:binary]} #{parameters} /dev/#{dev}`
      else
        test_file = File.open(config[:debug_file], "rb")
        output[dev] = test_file.read
        test_file.close
      end

      # check overall helath status
      if config[:overall] == 'on' && !output[dev].include?('SMART overall-health self-assessment test result: PASSED')
        criticals << "Overall health check failed on #{dev}"
      end

      output[dev].split("\n").each do |line|
        fields = line.split
        if fields.size == 10 && fields[0].to_i != 0 && attCheckList.include?(fields[0].to_i)
          smartAtt = @smartAttributes.find{|att| att[:id] == fields[0].to_i}
          attValue = fields[9].to_i
          attValue = self.send(smartAtt[:read], attValue) unless smartAtt[:read].nil?
          if attValue < smartAtt[:crit_min] || attValue > smartAtt[:crit_max]
            criticals << "#{dev} critical #{fields[0]} #{smartAtt[:name]}: #{attValue}"
            puts "#{fields[0]} #{smartAtt[:name]}: #{attValue} (critical)" if @smartDebug
          elsif attValue < smartAtt[:warn_min] || attValue > smartAtt[:warn_max]
            warnings << "#{dev} warning #{fields[0]} #{smartAtt[:name]}: #{attValue}"
            puts "#{fields[0]} #{smartAtt[:name]}: #{attValue} (warning)" if @smartDebug
          else
            puts "#{fields[0]} #{smartAtt[:name]}: #{attValue} (ok)" if @smartDebug
          end
        end
      end
      puts "\n\n" if @smartDebug
    end

    # check the result
    if criticals.size != 0
      critical criticals.concat(warnings).join("\n")
    elsif warnings.size != 0
      warning warnings.join("\n")
    else
      ok "All device operating properly"
    end
  end

  # Get right 16 bit from raw48
  def right16bit(value)
    value & 0xffff
  end

  # Get left 16 bit from raw48
  def left16bit(value)
    value >> 32
  end

  # find all devices from /proc/partitions or from parameter
  def findDevices
    # Return parameter value if it's defined
    return config[:devices].split(',') unless config[:devices] == 'all'

    # List all device and split it by new line
    all = `cat /proc/partitions`.split("\n")

    # Delete first two row (header and empty line)
    (1..2).each {all.delete_at(0)}

    # Search for devices without number
    devices = []
    all.each do |line|
      partition = line.scan(/\w+/).last.scan(/^\D+$/).first
      devices << partition unless partition.nil?
    end

    devices
  end

  # find all attribute id from parameter or json file
  def findAttributes
    return config[:attributes].split(',') unless config[:attributes] == 'all'

    attributes = []
    @smartAttributes.each do |att|
      attributes << att[:id]
    end

    attributes
  end
end
