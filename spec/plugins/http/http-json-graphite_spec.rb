#! /usr/bin/env ruby
#
#   http-json-graphite_spec
#
# DESCRIPTION:
#
# OUTPUT:
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#
# USAGE:
#
# NOTES:
#
#
require_relative '../../../plugins/http/http-json-graphite'
require_relative '../../../spec_helper'

describe HttpJsonGraphite do

  it 'is able to parse json and output graphite data' do

    input_file = File.open('spec/fixtures/plugins/http/input.json', 'r')
    data = input_file.read
    input_file.close

    RestClient.stub(:get).and_return(data)

    expected = expect do
      begin
        checker = HttpJsonGraphite.new
        checker.config[:object] = 'value'
        checker.config[:metric] = 'Connections::numConnections,BusyConnections::numBusyConnections'
        checker.config[:scheme] = 'localhost.c3p0'
        checker.config[:url] = 'http://localhost:8080'
        checker.run
      rescue SystemExit
        puts
      end
    end
    expected.to output(/localhost.c3p0.Connections 15\s\d+\nlocalhost.c3p0.BusyConnections 0\s\d+/).to_stdout
  end

end
