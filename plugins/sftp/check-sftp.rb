#!/usr/bin/env ruby
#
# check-sftp.rb
# ===
#
# Description
#   Provides checks against an sFTP site.
#
#   1)  SFTP Connection Testing
#   2)  File Writes
#   3)  File Count Exceeding
#   4)  Files Older Than
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

# Checks sFTP site
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
    :description => "Directory to use for file checks",
    :default => "/"

  option :match,
    :short => "-m MATCH",
    :long => "--match MATCH",
    :description => "Match files with this pattern for counting/file aging checks (**, **/*)."

  option :check_prefix,
    :short => "-x PREFIX",
    :description => "Prefix for temporary file write check. Blank for none."

  option :check_count,
    :short => "-n COUNT",
    :long => "--number COUNT",
    :proc => proc { |a| a.to_i },
    :description => "Alert if files > COUNT in directory"

  option :check_older,
    :short => "-o OLDER_THAN",
    :long => "--older_than OLDER_THAN",
    :proc => proc { |a| a.to_i },
    :description => "Alert if any file age > OLDER_THAN seconds"

  def run
    if sftp
      check_file_write
      check_file_count
      check_file_age
    end

    ok
  rescue Timeout::Error
    critical "Timed out after #{config[:timeout]}s"
  rescue SocketError => e
    critical "Could not connect: #{e.inspect}"
  rescue Net::SSH::AuthenticationFailed
    critical "Failed authentication with #{config[:username]}"
  rescue Net::SFTP::StatusException => e
    critical "SFTP Error - #{e.message}"
  rescue => e
    critical "Unexpected error; #{e.inspect}"
  end

  private

  def check_file_write
    if config[:check_prefix]
      io = StringIO.new("Generated from Sensu at "+Time.now.to_s)
      remote_path = File.join('', config[:directory], config[:check_prefix]+"_#{Time.now.to_i}.txt")
      sftp.upload!(io, remote_path)
      sftp.remove!(remote_path)
    end
  end

  def check_file_count
    if config[:check_count]
      if matching_files.count > config[:check_count]
        critical "Too many files - #{config[:directory]} has #{matching_files.count} matching files"
      end
    end
  end

  def check_file_age
    if config[:check_older]
      run_at    = Time.now
      old_files = matching_files.find_all { |f| (run_at.to_i - f.attributes.mtime) > config[:check_older] }
      unless old_files.empty?
        critical "Files too old - #{config[:directory]} has #{old_files.count} matching files older than #{config[:check_older]}s"
      end
    end
  end

  def matching_files
    @matching_files ||= sftp.dir.glob(config[:directory], config[:match]).find_all { |f| f.attributes.file? }
  end

  def sftp
    @sftp ||= Net::SFTP.start(config[:host], config[:username], :password => config[:password], :timeout => config[:timeout], :port => config[:port])
  end
end
