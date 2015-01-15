#!/usr/bin/env ruby
#
# check-supervisor-socket
#
#
# DESCRIPTION:
#   Check all supervisor processes are running#
#
# OUTPUT:
#   Plain text, 'All processes running' or eg. 'redis-server not running: FATAL'
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: uby-supervisor
#
# USAGE:
#   check-supervisor-socket.rb
#
# LICENSE:
#    Copyright (c) 2013 Double Negative Limited and Johan van den Dorpe
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'rubygems' if RUBY_VERSION < '1.9'
require 'sensu-plugin/check/cli'
require 'ruby-supervisor'

class CheckSupervisor < Sensu::Plugin::Check::CLI
  option :host,
         description: 'Hostname to check',
         short: '-H HOST',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'Supervisor port',
         short: '-p PORT',
         long: '--port PORT',
         default: 9001

  option :critical,
         description: 'Supervisor states to consider critical',
         short: '-c STATE[,STATE...]',
         long: '--critical STATE[,STATE...]',
         proc: proc { |v| v.upcase.split(',') },
         default: ['FATAL']

  option :help,
         description: 'Show this message',
         short: '-h',
         long: '--help'

  def run
    if config[:help]
      puts opt_parser
      exit
    end

    begin
      @super = RubySupervisor::Client.new(config[:host], config[:port])
    rescue
      critical "Tried to access #{config[:host]} but failed"
    end

    @super.processes.each do |process|
      critical "#{process['name']} not running: #{process['statename'].downcase}" if config[:critical].include?(process['statename'])
    end

    ok 'All processes running'
  end # def run
end # class CheckSupervisor
