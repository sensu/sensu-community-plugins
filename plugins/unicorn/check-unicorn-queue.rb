#!/usr/bin/env ruby
#
# Checks Unicorn Queue
# ===
#
# DESCRIPTION:
#   This plugin checks the queue of Unicorn (a Rack HTTP server)
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   linux
#   bsd
#
# DEPENDENCIES:
#   sensu-plugin ruby gem
#   raindrops ruby gem
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'raindrops'

class CheckUnicornQueue < Sensu::Plugin::Check::CLI

  option :addr,
    :short => '-a address'

  option :socket,
    :short => '-s socket'

  option :warn,
    :short => '-w warn',
    :proc => proc { |w| w.to_i }
  
  option :critical,
    :short => '-c critical',
    :proc => proc { |w| w.to_i }

  def run
    @queued = queued
    unknown "QUEUE STATUS - #{@queued.inspect}" unless @queued
    critical "#{@queued} QUEUED" if @queued >= config[:critical]
    warn "#{@queued} QUEUED" if @queued >= config[:warn]
    ok "#{@queued} QUEUED"
  end

  def queued
    if config[:addr]
      Raindrops::Linux
      .tcp_listener_stats(config[:addr].split(','))[0].queued
    elsif config[:socket]
      Raindrops::Linux
      .unix_listener_stats(config[:socket].split(','))[0].queued
    end
  end 
end
