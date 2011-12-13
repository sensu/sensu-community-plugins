#!/usr/bin/env ruby

require 'sensu-plugin/check/cli'

class Trivial < Sensu::Plugin::Check::CLI

  option :fail,
         :description => "Simulate failure",
         :boolean => true,
         :short => '-f',
         :long => '--fail'

  def run
    if config[:fail]
      critical "Something went wrong"
    else
      ok "All is well"
    end
  end

end
