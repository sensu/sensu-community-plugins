#! /usr/bin/env ruby
#
#   check-disk-fail
#
# DESCRIPTION:
#   Check for failing disks
#   Greps through dmesg output looking for indications that a drive is failing.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Coppyright 07/14/2014 Shane Feek and  Alan Smith.
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckDiskFail < Sensu::Plugin::Check::CLI
  def run
    dmesg = `dmesg`.lines

    %w(Read Write Smart).each do |v|
      found = dmesg.grep(/failed command\: #{v.upcase}/)
      # #YELLOW
      unless found.empty?  # rubocop:disable IfUnlessModifier
        critical "Disk #{v} Failure"
      end
    end

    ok
  end
end
