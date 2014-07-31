#!/usr/bin/env ruby
#
# Pushes metrics plugin output to geckoboard.
# ===
#
# TODO: Add more options for output to geckoboard
#
# Copyright 2012 Pete Shima <me@peteshima.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'geckoboard-push'

class GeckoboardPush < Sensu::Handler

  # Override filters from Sensu::Handler. not appropriate for metric handlers
  def filter; end

  def handle
    Geckoboard::Push.api_key = settings["geckoboard"]["api_key"]

    checks = settings["geckoboard"]["checks"]

    metrics = @event['check']['output']

    all = []

    # Probably a better way to do this than loop over the output twice
    metrics.split(/\n/).each do |m|
      v = m.split(/\t/)
      all << {:value => v[1], :label => v[0]}
    end

    metrics.split(/\n/).each do |m|
      v = m.split(/\t/)
      if checks.has_key?(v[0])
        c = settings["geckoboard"]["checks"][v[0]]
        wk = c["widget_key"]

        case c["type"]
        when "number_and_secondary_value"
          Geckoboard::Push.new(wk).number_and_secondary_value(v[1], v[1])
        when "geckometer"
          Geckoboard::Push.new(wk).geckometer(v[1], c["min"], c["max"])
        when "piechart"
          Geckoboard::Push.new(wk).pie(all)
        when "funnel"
          Geckoboard::Push.new(wk).funnel(all)
        end
      end

    end

  end

end
