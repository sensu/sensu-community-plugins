#!/usr/bin/env ruby
#
# Transactional check to make sure CAS
# (Central Authentification Service) is
# functional.
# ===
#
# Requirements
# ===
#
# Requires the 'mechanize' gem.
#
# Jean-Francois Theroux <me@failshell.io>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'mechanize'
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckCAS < Sensu::Plugin::Check::CLI

  option :url,
    :description => 'CAS login URL',
    :short => '-u',
    :long => '--url URL',
    :required => true

  option :login,
    :description => 'CAS login user',
    :short => '-l',
    :long => '--login USER',
    :required => true

  option :password,
    :description => 'CAS login password',
    :short => '-p',
    :long => '--password PASSWORD',
    :required => true

  def check_cas
    a = Mechanize.new { |agent| agent.follow_meta_refresh = true }

    a.get(config[:url]) do |home_page|
      home_page.parser.css('input').each do |e|
        if e['name'] == 'lt'
          @lt = e['value']
        elsif e['name'] == 'execution'
          @exec = e['value']
        elsif e['name'] == '_eventId'
          @eventid = e['value']
        end
      end

      home_page.forms[0]['username'] = config[:login]
      home_page.forms[0]['password'] = config[:password]
      home_page.forms[0]['lt'] = @lt
      home_page.forms[0]['execution'] = @exec
      home_page.forms[0]['_eventId'] = @eventid
      res = home_page.forms[0].submit

      if res.at('div.success')
        ok 'CAS login successful'
      elsif res.at('div.errors')
        critical 'CAS login failed'
      else
        unknown 'Unknown condition'
      end
    end
  end

  def run
    check_cas
  end

end
