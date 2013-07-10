#!/usr/bin/env ruby
#
# Gearman Plugin
# ===
#
# This plugin checkes the status of gearman
#
# Copyright 2013 Siavash Safi https://github.com/siavashs
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'gearman/server'

class CheckGearman < Sensu::Plugin::Check::CLI

  @@status = {}

  option :hostname,
         :description => "Hostname to login to",
         :short => '-h HOST',
         :long => '--hostname HOST',
         :default => "localhost"

  option :port,
         :description => "Port to connect to",
         :short => '-p PORT',
         :long => '--port PORT',
         :default => "4730"

  option :functions,
         :description => "List of functions (comma separated)",
         :short => '-f FUN1,FUN2,...',
         :long => '--functions FUN1,FUN2,...'

  option :queue,
         :description => "Warning and Critical number of jobs in the queue",
         :short => '-q WARNING,CRITICAL',
         :long => '--queue WARNING,CRITICAL'

  option :workers,
         :description => "Warning and Critical number of available workers",
         :short => '-w WARNING,CRITICAL',
         :long => '--workers WARNING,CRITICAL'

  option :active,
         :description => "Warning and Critical number of active workers",
         :short => '-a WARNING,CRITICAL',
         :long => '--active WARNING,CRITICAL'

  def check_func(f)
    if @@status[f]
      check_queue(f) if config[:queue]
      check_workers(f) if config[:workers]
      check_active(f) if config[:active]
    else
      critical "No suck function: #{f}"
    end
  end

  def check_queue(f)
    w,c = config[:queue].split(",").map(&:to_i)

    queue = @@status[f][:queue].to_i
    case
    when queue > c
      critical "#{@@status[f][:queue]} jobs are in #{f} function queue!"
    when queue > w
      warning "#{@@status[f][:queue]} jobs are in #{f} function queue!"
    end
  end

  def check_workers(f)
    w,c = config[:workers].split(",").map(&:to_i)

    workers = @@status[f][:workers].to_i
    case
    when workers < c
      critical "#{@@status[f][:workers]} workers are available in #{f} function!"
    when workers < w
      warning "#{@@status[f][:workers]} workers are available in #{f} function!"
    end
  end

  def check_active(f)
    w,c = config[:active].split(",").map(&:to_i)

    active = @@status[f][:active].to_i
    case
    when active < c
      critical "#{@@status[f][:active]} workers are active in #{f} function!"
    when active < w
      warning "#{@@status[f][:active]} workers are active in #{f} function!"
    end
  end

  def run
    begin
      server = Gearman::Server.new(config[:hostname] + ":" + config[:port])

      @@status = server.status
      if config[:functions]
        config[:functions].split(",").each do |func|
          check_func(func)
        end
      end
      ok "All checks passed!"
    rescue Gearman::ServerDownException => e
      critical "Error message: #{e}"
    end
  end
end
