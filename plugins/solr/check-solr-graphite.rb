#!/usr/bin/env ruby
#
# Push Apache Solr stats into graphite
# ===
#
# Created by Pete Shima - me@peteshima.com
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# TODO - Narrow down needed stats, find a cleaner way to parse the xml
#

require "rubygems" if RUBY_VERSION < "1.9.0"
require 'sensu-plugin/metric/cli'
require 'net/http'
require 'json'
require 'uri'
require 'crack'

class SolrGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "Solr Host to connect to",
    :required => true

  option :port,
    :short => "-p PORT",
    :long => "--port PORT",
    :description => "Solr Port to connect to",
    :proc => proc {|p| p.to_i },
    :required => true

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.solr"


  def run
    ping_url = "http://#{config[:host]}:#{config[:port]}/solr/admin/ping?wt=json"


    resp = Net::HTTP.get_response(URI.parse(ping_url))
    ping = JSON.parse(resp.body)


    output "#{config[:scheme]}.solr.QueryTime", ping["responseHeader"]["QTime"]
    output "#{config[:scheme]}.solr.Status", ping["responseHeader"]["status"]


    stats_url = "http://#{config[:host]}:#{config[:port]}/solr/admin/stats.jsp"

    xml_data = Net::HTTP.get_response(URI.parse(stats_url)).body.gsub("\n","")
    stats  = Crack::XML.parse(xml_data)

    #this xml is an ugly beast.
    core_searcher = stats["solr"]["solr_info"]["CORE"]["entry"].find_all {|v| v["name"].strip! == "searcher"}.first["stats"]["stat"]
    standard = stats["solr"]["solr_info"]["QUERYHANDLER"]["entry"].find_all {|v| v["name"].strip! == "standard"}.first["stats"]["stat"]
    update = stats["solr"]["solr_info"]["QUERYHANDLER"]["entry"].find_all {|v| v["name"] == "/update"}.first["stats"]["stat"]
    updatehandler = stats["solr"]["solr_info"]["UPDATEHANDLER"]["entry"]["stats"]["stat"]
    querycache = stats["solr"]["solr_info"]["CACHE"]["entry"].find_all {|v| v["name"].strip! == "queryResultCache"}.first["stats"]["stat"]
    documentcache = stats["solr"]["solr_info"]["CACHE"]["entry"].find_all {|v| v["name"] == "documentCache"}.first["stats"]["stat"]
    filtercache = stats["solr"]["solr_info"]["CACHE"]["entry"].find_all {|v| v["name"] == "filterCache"}.first["stats"]["stat"]

    output "#{config[:scheme]}.solr.core.maxdocs", core_searcher[2].strip!
    output "#{config[:scheme]}.solr.core.maxdocs", core_searcher[3].strip!
    output "#{config[:scheme]}.solr.core.warmuptime", core_searcher[9].strip!

    output "#{config[:scheme]}.solr.queryhandler.standard.requests", standard[1].strip!
    output "#{config[:scheme]}.solr.queryhandler.standard.errors", standard[2].strip!
    output "#{config[:scheme]}.solr.queryhandler.standard.timeouts", standard[3].strip!
    output "#{config[:scheme]}.solr.queryhandler.standard.totaltime", standard[4].strip!
    output "#{config[:scheme]}.solr.queryhandler.standard.timeperrequest", standard[5].strip!
    output "#{config[:scheme]}.solr.queryhandler.standard.requestspersecond", standard[6].strip!

    output "#{config[:scheme]}.solr.queryhandler.update.requests", update[1].strip!
    output "#{config[:scheme]}.solr.queryhandler.update.errors", update[2].strip!
    output "#{config[:scheme]}.solr.queryhandler.update.timeouts", update[3].strip!
    output "#{config[:scheme]}.solr.queryhandler.update.totaltime", update[4].strip!
    output "#{config[:scheme]}.solr.queryhandler.update.timeperrequest", update[5].strip!
    output "#{config[:scheme]}.solr.queryhandler.update.requestspersecond", standard[6].strip!

    output "#{config[:scheme]}.solr.queryhandler.updatehandler.commits", updatehandler[0].strip!
    output "#{config[:scheme]}.solr.queryhandler.updatehandler.autocommits", updatehandler[3].strip!
    output "#{config[:scheme]}.solr.queryhandler.updatehandler.optimizes", updatehandler[4].strip!
    output "#{config[:scheme]}.solr.queryhandler.updatehandler.rollbacks", updatehandler[5].strip!
    output "#{config[:scheme]}.solr.queryhandler.updatehandler.docspending", updatehandler[7].strip!
    output "#{config[:scheme]}.solr.queryhandler.updatehandler.adds", updatehandler[8].strip!
    output "#{config[:scheme]}.solr.queryhandler.updatehandler.errors", updatehandler[11].strip!
    output "#{config[:scheme]}.solr.queryhandler.updatehandler.cumulativeadds", updatehandler[12].strip!
    output "#{config[:scheme]}.solr.queryhandler.updatehandler.cumulativeerrors", updatehandler[15].strip!

    output "#{config[:scheme]}.solr.queryhandler.querycache.lookups", querycache[0].strip!
    output "#{config[:scheme]}.solr.queryhandler.querycache.hits", querycache[1].strip!
    output "#{config[:scheme]}.solr.queryhandler.querycache.hitRatio", querycache[2].strip!
    output "#{config[:scheme]}.solr.queryhandler.querycache.inserts", querycache[3].strip!
    output "#{config[:scheme]}.solr.queryhandler.querycache.size", querycache[5].strip!
    output "#{config[:scheme]}.solr.queryhandler.querycache.warmuptime", querycache[6].strip!
    output "#{config[:scheme]}.solr.queryhandler.querycache.cumulativelookups", querycache[7].strip!
    output "#{config[:scheme]}.solr.queryhandler.querycache.cumulativehits", querycache[8].strip!
    output "#{config[:scheme]}.solr.queryhandler.querycache.cumulativehitratio", querycache[9].strip!
    output "#{config[:scheme]}.solr.queryhandler.querycache.cumulativeinserts", querycache[10].strip!

    output "#{config[:scheme]}.solr.queryhandler.documentcache.lookups", documentcache[0].strip!
    output "#{config[:scheme]}.solr.queryhandler.documentcache.hits", documentcache[1].strip!
    output "#{config[:scheme]}.solr.queryhandler.documentcache.hitRatio", documentcache[2].strip!
    output "#{config[:scheme]}.solr.queryhandler.documentcache.inserts", documentcache[3].strip!
    output "#{config[:scheme]}.solr.queryhandler.documentcache.size", documentcache[5].strip!
    output "#{config[:scheme]}.solr.queryhandler.documentcache.warmuptime", documentcache[6].strip!
    output "#{config[:scheme]}.solr.queryhandler.documentcache.cumulativelookups", documentcache[7].strip!
    output "#{config[:scheme]}.solr.queryhandler.documentcache.cumulativehits", documentcache[8].strip!
    output "#{config[:scheme]}.solr.queryhandler.documentcache.cumulativehitratio", documentcache[9].strip!
    output "#{config[:scheme]}.solr.queryhandler.documentcache.cumulativeinserts", documentcache[10].strip!

    output "#{config[:scheme]}.solr.queryhandler.filtercache.lookups", filtercache[0].strip!
    output "#{config[:scheme]}.solr.queryhandler.filtercache.hits", filtercache[1].strip!
    output "#{config[:scheme]}.solr.queryhandler.filtercache.hitRatio", filtercache[2].strip!
    output "#{config[:scheme]}.solr.queryhandler.filtercache.inserts", filtercache[3].strip!
    output "#{config[:scheme]}.solr.queryhandler.filtercache.size", filtercache[5].strip!
    output "#{config[:scheme]}.solr.queryhandler.filtercache.warmuptime", filtercache[6].strip!
    output "#{config[:scheme]}.solr.queryhandler.filtercache.cumulativelookups", filtercache[7].strip!
    output "#{config[:scheme]}.solr.queryhandler.filtercache.cumulativehits", filtercache[8].strip!
    output "#{config[:scheme]}.solr.queryhandler.filtercache.cumulativehitratio", filtercache[9].strip!
    output "#{config[:scheme]}.solr.queryhandler.filtercache.cumulativeinserts", documentcache[10].strip!


    ok


  end

end
