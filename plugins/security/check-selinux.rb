#!/usr/bin/env ruby
# encoding UTF-8
#   check-selinux.rb
#
# DESCRIPTION:
#   By default, checks to see if selinux is enforcing.
#   Setting -d will reverse this, and check to see if it is disabled.
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# PLATFORMS:
#   Linux
#
# USAGE:
#   /usr/bin/ruby plugins/security/check-selinux.rb
#   /usr/bin/ruby plugins/security/check-selinux.rb -d
#
# NOTES:
#
# LICENSE:
#   Jacob Royal j.w.r.1215@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class SELinuxCheck < Sensu::Plugin::Check::CLI
  option :disabled,
         short: '-d',
         long: '--disabled',
         description: 'check that SELinux is disabled',
         required: false

  def enforcing?(check)
    if check.downcase == 'enforcing'
      true
    else
      false
    end
  end

  def run
    check = `getenforce`.chomp

    if config[:disabled]
      if enforcing?(check)
        critical 'SELinux is being enforced'
      else
        ok 'SELinux is disabled'
      end
    else
      if enforcing?(check)
        ok 'SELinux is being enforced'
      else
        critical 'SELinux is disabled'
      end
    end

  rescue
    message 'Error while attempting to execute script'
    exit 1
  end
end
