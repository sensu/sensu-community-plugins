#!/usr/bin/env ruby
#
# Check OS API
# ===
#
# Purpose: to check openstack service api endpoint.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckOSApi < Sensu::Plugin::Check::CLI
  option :service, :long  => '--service SERVICE_TYPE'

  ##
  # Build a command to execute, since this is passed directly
  # to Kernel#system.

  def safe_command
    cmd = case config[:service]
    when "nova"
      "nova list"
    when "glance"
      "glance index"
    when "keystone"
      "keystone endpoint-list"
    end

    ". /root/stackrc; #{cmd}"
  end

  def run
    system("#{safe_command}")

    if $?.exitstatus == 0
      ok
    else
      critical
    end
  end
end
