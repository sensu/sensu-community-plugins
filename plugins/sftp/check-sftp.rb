#!/usr/bin/env ruby
#
# check-sftp.rb
# ===
#
# Description
#   Connects to sFTP, optionally writes a small file with a random name, then disconnects.
#
# Dependencies
# - net-sftp
#
#  Author Charles Cooke   <charles@coupa.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
gem 'net-sftp', '~> 2.1.0'
require 'net/sftp'

# Checks sFTP site for availability
class CheckSftp < Sensu::Plugin::Check::CLI
  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "Sftp Host",
    :required => true

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "Sftp Port",
    :proc => proc { |p| p.to_i },
    :default => 22

  option :username,
    :short => "-u USERNAME",
    :long => "--user USERNAME",
    :description => "Sftp Username",
    :required => true

  option :password,
    :short => "-s PASSWORD",
    :long => "--pass PASSWORD",
    :description => "Sftp Password",
    :default => "",
    :required => true

  option :timeout,
    :short => "-t TIMEOUT",
    :long => "--timeout TIMEOUT",
    :proc => proc { |a| a.to_i },
    :description => "Sftp Timeout",
    :default => 60

  option :directory,
    :short => "-d DIRECTORY",
    :long => "--directory DIRECTORY",
    :description => "Directory to use for writing temporary file (eg. /My/Path) - blank for none"

  option :prefix,
    :short => "-x PREFIX",
    :description => "Prefix for temporary file",
    :default => "sensu"

  def run
    Net::SFTP.start(config[:host], config[:username], :password => config[:password], :timeout => config[:timeout], :port => config[:port]) do |sftp|
      if config[:directory] && !config[:directory].empty?
        io = StringIO.new("Generated from Sensu at "+Time.now.to_s)
        remote_path = File.join('', config[:directory], config[:prefix]+"_#{Time.now.to_i}.txt")
        sftp.upload!(io, remote_path)
        sftp.remove!(remote_path)
      end
    end

    ok
  rescue Timeout::Error
    critical "Timed out after #{config[:timeout]}s"
  rescue SocketError => e
    critical "Could not connect: #{e.inspect}"
  rescue Net::SSH::AuthenticationFailed => e
    critical "Failed authentication with #{config[:username]}"
  rescue Net::SFTP::StatusException => e
    critical "SFTP Error - #{e.message}"
  rescue
    critical "Unexpected error; #{e.inspect}"
  end
end
