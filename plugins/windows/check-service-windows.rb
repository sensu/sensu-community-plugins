#! /usr/bin/env ruby
#
#   check-service-windows
#
# DESCRIPTION:
#   Check Named Windows Service Plugin
#   This plugin checks whether a User-inputted service on Windows is running or not
#   This checks users tasklist tool to find any service on Windows is running or not.

#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Windows
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Edited from  <jashishtech@gmail.com>
#   Copyright 2014 <jj.asghar@peopleadmin.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckWinService < Sensu::Plugin::Check::CLI
  option :service,
         description: 'Check for a specific service',
         long: '--service SERVICE',
         short: '-s SERVICE'

  def run
    temp = system('tasklist /svc|findstr /i ' + config[:service])
    if temp == false
      message config[:service] + ' is not running'
      critical
    else
      message config[:service] + ' is running'
      ok
    end
  end
end
