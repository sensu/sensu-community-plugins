#!/usr/bin/env ruby
#
# This handler logs last settings['logevent']['keep'] json events in files as
# settings['logevent']['eventdir']/client/check_name/timestamp.action
#
# Copyright 2013 Piavlo <lolitushka@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'json'
require 'fileutils'

class LogEvent < Sensu::Handler
  def handle
    eventdir = "#{settings['logevent']['eventdir']}/#{@event['client']['name']}/#{@event['check']['name']}"
    FileUtils.mkdir_p(eventdir)

    File.open("#{eventdir}/#{@event['check']['executed']}.#{@event['action']}", 'w') do |f|
      f.write(JSON.pretty_generate(@event))
    end

    events = Dir.glob("#{eventdir}/*.#{@event['action']}")
    # #YELLOW
    if settings['logevent']['keep'] < events.length # rubocop:disable GuardClause
      FileUtils.rm_f(events.sort.reverse.shift(settings['logevent']['keep']))
    end
  end
end
