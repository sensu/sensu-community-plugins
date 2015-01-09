#! /usr/bin/env ruby
# encoding: UTF-8

#   check-gpg-expiration
#
# DESCRIPTION:
#   This will check if given GPG key ID is about to expire.
#   Optionally you can specify the GPG homedir
#
# OUTPUT:
#   plain text
#   Defaults: CRITICAL if key ID is about to expire in 30 days
#             WARNING if key ID is about expire in 60 days
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: csv
#   gem: open3
#   gem: date
#   gem: time
#   GPG
#
# USAGE:
#   check-gpg-expiration.rb -i <GPG_KEY_ID>
#   check-gpg-expiration.rb -w 7 -c 2 -i <GPG_KEY_ID>
#
# LICENSE:
#   Yasser Nabi yassersaleemi@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'csv'
require 'open3'
require 'date'
require 'time'

# Use to see if any processes require a restart
class CheckGpgExpire < Sensu::Plugin::Check::CLI
  option :warn,
         short: '-w WARN',
         default: 60

  option :crit,
         short: '-c CRIT',
         default: 30

  option :homedir,
         short: '-h GPG_HOMEDIR',
         long: '--homedir GPG_HOMEDIR'

  option :id,
         short: '-i GPG_KEY_ID',
         long: '--id GPG_KEY_ID',
         required: true

  GPG = '/usr/bin/gpg'

  # Set things up
  def initialize
    super
  end

  # Helper method that returns the number of days since epoch
  # from a given epoch parameter
  def days_since_epoch(e)
    epoch = Date.new(1970, 1, 1)
    d = Time.at(e).to_date
    (d - epoch).to_i
  end

  # Run the GPG command and return the expiration date in epoch
  def key_expire
    return_val = [false, nil]
    args = ['--with-colons', '--fixed-list-mode', '--list-key', config[:id]]
    gpg_cmd = config[:homedir].nil? ? [GPG] + args : [GPG, "--homedir #{config[:homedir]}"] + args
    cmd_out, cmd_err, status = Open3.capture3 gpg_cmd.join ' '
    if status.success?
      CSV.parse(cmd_out, col_sep: ':') do |row|
        return_val = [true, row[6].to_i]  if row[0] == 'pub'
      end
    else
      return_val = [false, cmd_err]
    end
    return_val
  end

  # Check the GPG key expiration against today
  def check_gpg
    today_epoch = Date.today.to_time.to_i
    success, out = key_expire
    return_val = success ? days_since_epoch(out) - days_since_epoch(today_epoch) : out
    return_val.to_s
  end

  def run
    output = check_gpg
    case output
    when /^-\d+$/
      message "Key #{config[:id]} has expired!"
      critical
    when /^\d+$/
      message "Key #{config[:id]} has #{output} day(s) until it expires"
      warning if output.to_i <= config[:warn] && output.to_i > config[:crit]
      critical if output.to_i <= config[:crit]
      ok
    else
      message output
      unknown
    end
  end
end
