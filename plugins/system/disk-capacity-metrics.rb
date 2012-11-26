#!/usr/bin/env ruby
#
# System Load Stats Plugin
# ===
#
# This plugin uses df to collect disk capacity metrics
# disk-metrics.rb looks at /proc/stat which doesnt hold capacity metricss.
# could have intetrated this into disk-metrics.rb, but thought I'd leave it up to
# whomever implements the checks. 
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class DiskCapacity < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
         :description => "Metric naming scheme, text to prepend to .$parent.$child",
         :long => "--scheme SCHEME",
         :default => "#{Socket.gethostname}.disk"

  def convert_integers(values)
    values.each_with_index do |value, index|
      begin
        converted = Integer(value)
        values[index] = converted
      rescue ArgumentError
      end
    end
    values
  end

  def run
    #get capacity metrics from DF as they don't appear in /proc (to my knowledge anyway)
    `df -PT`.split("\n").drop(1).each do |line|
      begin
        fs, type, blocks, used, avail, capacity, mnt = line.split
        if mnt == "/"
          mnt = "root"
        end
        timestamp = Time.now.to_i
        if fs.match('/dev')
          fs = fs.gsub('/dev/','')
          metrics = {
              :disk=> {
                  "#{fs}.used" => used,
                  "#{fs}.avail" => avail,
                  "#{fs}.capacity" => capacity.gsub('%','')
              }
          }
          metrics.each do |parent, children|
            children.each do |child, value|
              output [config[:scheme], parent, child].join("."), value, timestamp
            end
          end
        end
      rescue
        unknown "malformed line from df: #{line}"
      end
    end

    #get inode capacity metrics
    `df -Pi`.split("\n").drop(1).each do |line|
      begin
        fs, inodes, used, avail, capacity, mnt = line.split
        if mnt == "/"
          mnt = "root"
        end
        timestamp = Time.now.to_i
        if fs.match('/dev')
          fs = fs.gsub('/dev/','')
          metrics = {
              :disk=> {
                  "#{fs}.iused" => used,
                  "#{fs}.iavail" => avail,
                  "#{fs}.icapacity" => capacity.gsub('%','')
              }
          }
          metrics.each do |parent, children|
            children.each do |child, value|
              output [config[:scheme], parent, child].join("."), value, timestamp
            end
          end
        end
      rescue
        unknown "malformed line from df: #{line}"
      end
    end
    ok
  end
end
