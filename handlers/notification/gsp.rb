#!/usr/bin/env ruby
#
# Sensu Google Spreadsheet Handler
# ===
#
# Google Spreadsheet handler has following options:
#  - sheet: Spreadsheet Sheet ID
#  - username: Google Account E-mail Address
#  - apppassword: Google Application Password
#
# Yohei Kawahara <inokara@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'google_drive'
require 'timeout'

class GAS < Sensu::Handler
  def sheet
    settings['gas']['sheet']
  end

  def username
    settings['gas']['username']
  end

  def apppassword
    settings['gas']['apppassword']
  end

  def event_tag
    action_to_string.downcase
  end

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def timestamp
    Time.at(@event['client']['timestamp'])
  end

  COLUMNS = {
    timestamp: 'timestamp',
    action: 'action',
    name: 'event_name',
    client: 'client',
    check_name: 'check_name',
    status: 'check_status',
    output: 'check_output',
    address: 'client_address',
    command: 'check_command',
    occurrences: 'occurrences',
    flapping: 'check_flapping'
  }

  def handle
    timeout(5) do
      session = GoogleDrive.login(username, apppassword)
      ws = session.spreadsheet_by_key(sheet).worksheets[0]
      ws.update_cells(1, 1, [COLUMNS.values])
      ws.save
      ws.list.push(
        COLUMNS[:timestamp] => timestamp,
        COLUMNS[:action] => action_to_string,
        COLUMNS[:name] => event_name,
        COLUMNS[:client] => @event['client']['name'],
        COLUMNS[:check_name] => @event['check']['name'],
        COLUMNS[:status] => @event['check']['status'],
        COLUMNS[:output] => @event['check']['status'],
        COLUMNS[:address] => @event['client']['address'],
        COLUMNS[:command] => @event['check']['command'],
        COLUMNS[:occurrences] => @event['occurrences'],
        COLUMNS[:flapping] => @event['check']['flapping']
      )
      ws.save
    end
  rescue Timeout::Error
    puts "Google SpreadSheet -- Timed out while attempting to send #{@event['action']} incident -- #{incident_key}"
  end
end
