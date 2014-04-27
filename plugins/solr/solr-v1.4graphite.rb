#!/usr/bin/env ruby
# Created by Mike Crocker
# Grab various metrics from apache-solr stats page
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'nokogiri'
require 'open-uri'

class SolrGraphite < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
    :short       => "-h HOST",
    :long        => "--host HOST",
    :description => "Solr host to connect to",
    :default     => "#{Socket.gethostname}"

  option :port,
    :short       => "-p PORT",
    :long        => "--port PORT",
    :description => "Solr port to connect",
    :proc        => proc {|p| p.to_i},
    :required    => true

  option :scheme,
    :short       => "-s SCHEME",
    :long        => "--scheme",
    :default     => "#{Socket.gethostname}"

  def lookingfor (needle, haystack)
    haystack.each_with_index do |element, index|
      if element.css('name').text.strip == needle
        return index
      else
        next
      end
    end
  end

  def outputstats (section, queryindex, statpage, metrics, label)
    metrics.each do |value|
      stat = statpage.css("#{section} entry")[queryindex].css("stats stat[name=#{value}]").text.strip
      output [config[:scheme], label, value].join("."), stat, Time.now.to_i
    end
  end

  def run

    # Capture initial stats page XML data. Sol4 1.4 takes a while to load stats page, the timeout accomidates that.
    doc = Nokogiri::XML(open("http://#{config[:host]}:#{config[:port]}/solr/admin/stats.jsp", :read_timeout => 300))

    # Go through each core and get the appropriate data
    doc.css('CORE entry').each do |coreinfo|
      output [config[:scheme], 'CORE', coreinfo.css('name').text.strip, 'numDocs'].join("."), coreinfo.css("stats stat[name='numDocs']").text.strip, \
             Time.now.to_i
      output [config[:scheme], 'CORE', coreinfo.css('name').text.strip, 'maxDoc'].join("."), coreinfo.css("stats stat[name='maxDoc']").text.strip, Time.now.to_i
      output [config[:scheme], 'CORE', coreinfo.css('name').text.strip, 'warmupTime'].join("."), coreinfo.css("stats stat[name='warmupTime']").text.strip, \
             Time.now.to_i
    end

    # Location of particular metric on our XML stat page
    indStandard   = lookingfor('standard', doc.css('QUERYHANDLER entry'))
    indUpdate     = lookingfor('/update', doc.css('QUERYHANDLER entry'))
    indUpdateHand = lookingfor('updateHandler', doc.css('UPDATEHANDLER entry'))
    indCache      = lookingfor('queryResultCache', doc.css('CACHE entry'))
    indDocCache   = lookingfor('documentCache', doc.css('CACHE entry'))
    indFilCache   = lookingfor('filterCache', doc.css('CACHE entry'))

    # All the metrics we're looking for
    statqueryhand  = Array['requests', 'errors', 'timeouts', 'avgTimePerRequest', 'avgRequestsPerSecond']
    statupdatehand = Array['commits', 'autocommits', 'optimizes', 'rollbacks', 'docsPending', 'adds', 'errors', 'cumulative_adds', \
                           'cumulative_errors']
    statcache      = Array['lookups', 'hits', 'hitratio', 'inserts', 'size', 'warmupTime', 'cumulative_lookups', 'cumulative_hits', \
                           'cumulative_hitratio', 'cumulative_inserts']

    name = doc.css('QUERYHANDLER entry')[indStandard].css('name').text.strip
    outputstats('QUERYHANDLER', indStandard, doc, statqueryhand, name)

    name = doc.css('QUERYHANDLER entry')[indUpdate].css('name').text.strip
    outputstats('QUERYHANDLER', indUpdate, doc, statqueryhand, name)

    name = doc.css('UPDATEHANDLER entry')[indUpdateHand].css('name').text.strip
    outputstats('UPDATEHANDLER', indUpdateHand, doc, statupdatehand, name)

    name = doc.css('CACHE entry')[indCache].css('name').text.strip
    outputstats('CACHE', indCache, doc, statcache, name)

    name = doc.css('CACHE entry')[indDocCache].css('name').text.strip
    outputstats('CACHE', indDocCache, doc, statcache, name)

    name = doc.css('CACHE entry')[indFilCache].css('name').text.strip
    outputstats('CACHE', indFilCache, doc, statcache, name)

    ok
  end
end
