#! /usr/bin/env ruby
#
#   check-process
#
# DESCRIPTION:
#   This plugin checks whether a User-inputted process is running or not
#   This checks users tasklist tool to find any process is running or not.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Windows
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2013 <jashishtech@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckDatabase < Sensu::Plugin::Check::CLI
  option :process, short: '-p process'

  def run
    temp = system('tasklist|findstr /i ' + config[:process])
    puts temp
    if temp == false
      message config[:process] + ' is not running'
      critical
    else
      message config[:process] + ' is running'
      ok
    end
  end
end
