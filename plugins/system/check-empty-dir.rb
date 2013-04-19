#!/usr/bin/env ruby
#
# Check if directory is empty
# ===
#
# Jean-Francois Theroux <failshell@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckEmptyDir < Sensu::Plugin::Check::CLI

  option :dir,
    :description => 'Directory to check',
    :short => '-d DIR',
    :long => '--dir DIR',
    :required => true

  def run
    ls = `ls #{config[:dir]}`
    if ls == ''
      critical "#{config[:dir]} is empty!"
    else
      ok "#{config[:dir]} is not empty."
    end
  end

end
