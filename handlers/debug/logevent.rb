#!/usr/bin/env ruby
#
# This handler logs json events in fs as client/check_name/timestamp.{create,resolve}
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'json'
require 'fileutils'

class LogEvent < Sensu::Handler

  def handle
    FileUtils.mkdir_p("#{settings['logevent']['eventdir']}/#{@event['client']['name']}/#{@event['check']['name']}")

    File.open("#{settings['logevent']['eventdir']}/#{@event['client']['name']}/#{@event['check']['name']}/#{Time.now.to_s.split[0]}@#{Time.now.to_s.split[1]}.#{@event['action']}",'w') do |f|
      f.write(JSON.pretty_generate(@event))
    end

    if settings['logevent']['keep'] < Dir.glob("#{settings['logevent']['eventdir']}/#{@event['client']['name']}/#{@event['check']['name']}/*.#{@event['action']}").length
      FileUtils.rm_f(Dir.glob("#{settings['logevent']['eventdir']}/#{@event['client']['name']}/#{@event['check']['name']}/*.#{@event['action']}").sort.first)
    end
  end

end
