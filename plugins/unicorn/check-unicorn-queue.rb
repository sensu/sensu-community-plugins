#!/usr/bin/env ruby
#
# check-unicorn-queue
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
#   gem: sensu-plugin
#   gem: raindrops
#
# USAGE:
#   check-unicorn-queue.rb -w 20 -c 50 -a 127.0.0.1:8080
#
# LICENSE:
#   Nathan Williams <nath.e.will@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'raindrops'

class CheckUnicornQueue < Sensu::Plugin::Check::CLI
  option :addr,
         short: '-a address',
         description: 'tcp address and port (e.g. 127.0.0.1:8080)'

  option :socket,
         short: '-s socket',
         description: 'path to unix socket (e.g. /run/unicorn.sock)'

  option :warn,
         short: '-w warn',
         proc: proc(&:to_i),
         description: 'request queue warn threshold'

  option :critical,
         short: '-c critical',
         proc: proc(&:to_i),
         description: 'request queue critical threshold'

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
