#! /usr/bin/env ruby
#
#   youtube-metrics
#
# DESCRIPTION:
#   Pull youtube video and subscriber metrics
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: Socket
#   gem: crack
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2012 Pete Shima <me@peteshima.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'net/http'
require 'net/https'
require 'crack'

class YoutubeMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :videoid,
         short: '-v VIDEOID',
         long: '--video VIDEOID',
         description: 'From any youtube video url  ex: watch?v=BBnRXO6ndGI, video ID is BBnRXO6ndGI',
         required: true

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.youtube"

  def run
    unless config[:videoid].nil?
      res = Net::HTTP.start('gdata.youtube.com', '80') do |http|
        req = Net::HTTP::Get.new("/feeds/api/videos/#{config[:videoid]}")
        http.request(req)
      end

      stats  = Crack::XML.parse(res.body)

      author =  stats['entry']['author']['name']
      comments = stats['entry']['gd:comments']['gd:feedLink']['countHint']
      likes = stats['entry']['gd:rating']['numRaters']
      favorites = stats['entry']['yt:statistics']['favoriteCount']
      views = stats['entry']['yt:statistics']['viewCount']

      channelres = Net::HTTP.start('gdata.youtube.com', '80') do |http|
        req = Net::HTTP::Get.new("/feeds/api/users/#{author}")
        http.request(req)
      end

      channel  = Crack::XML.parse(channelres.body)

      chansubs = channel['entry']['yt:statistics']['subscriberCount']
      chanviews = channel['entry']['yt:statistics']['viewCount']
      chanuploadviews = channel['entry']['yt:statistics']['totalUploadViews']

      name = author.gsub(/(\W)/, '_').downcase

      output "#{config[:scheme]}.video.#{config[:videoid]}.comments", comments
      output "#{config[:scheme]}.video.#{config[:videoid]}.likes", likes
      output "#{config[:scheme]}.video.#{config[:videoid]}.favorites", favorites
      output "#{config[:scheme]}.video.#{config[:videoid]}.views", views
      output "#{config[:scheme]}.channel.#{name}.subs", chansubs
      output "#{config[:scheme]}.channel.#{name}.views", chanviews
      output "#{config[:scheme]}.channel.#{name}.videoviews", chanuploadviews
    end

    ok
  end
end
