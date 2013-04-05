#!/usr/bin/env ruby
#
# GlusterFS node monitoring
# ===
#
# Copyright 2013 Jean-Francois Theroux <failshell@gmail.com>
#
# Requirements:
#
# - unless sensu-client runs as root, you need sudo access like this:
#       sensu ALL=(root) NOPASSWD:/usr/sbin/gluster
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckGlusterFSPeer < Sensu::Plugin::Check::CLI

  def get_peer_status
    begin
      if Process.uid == 0
        `gluster volume info`
      else
        `sudo gluster volume info`
      end

      unless $?.exitstatus == 0
        critical 'GlusterFS is not running!' + $?.exitstatus.to_s
      else
        ok 'GlusterFS is running.'
      end
    end
  end

  def run
    get_peer_status
  end

end
