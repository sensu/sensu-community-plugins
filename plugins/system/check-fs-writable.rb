#!/usr/bin/env ruby
#
# Check Filesystem Writability Plugin
# ===
#
# This plugin checks that a filesystem is writable. Useful for checking for stale NFS mounts.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'tempfile'

class CheckFSWritable < Sensu::Plugin::Check::CLI

  option :dir,
    :description => 'Directory to check for writability',
    :short => '-d DIRECTORY',
    :long => '--directory DIRECTORY'

  def run
    unknown 'No directory specified' unless config[:dir]
    critical "#{config[:dir]} does not exist " unless File.directory?(config[:dir])
    file = Tempfile.new('.sensu', config[:dir])
    begin
      file.write("mops") || critical('Could not write to filesystem')
      file.read || critical('Could not read from filesystem')
    ensure
      file.close
      file.unlink
    end
    ok "#{config[:dir]} is OK"
  end

end
