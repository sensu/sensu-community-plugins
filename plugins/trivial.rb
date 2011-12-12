#!/usr/bin/env ruby

require 'sensu-plugin/check/cli'

class Trivial < Sensu::Plugin::Check::CLI

  def run
    ok "All is well"
  end

end
