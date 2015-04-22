#! /usr/bin/env ruby
#
#   check-http-json_spec
#
# DESCRIPTION:
#
# OUTPUT:
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: check-http-json
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require_relative '../../../plugins/http/check-http-json'
require_relative '../../../spec_helper'

require 'webmock/rspec'

describe CheckJson, 'run' do

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  def stub_with_webmock(resp_json)
    stub_request(:get, 'https://example.com:45699/health/check')
    .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Ruby' })
    .to_return(status: 200, body: resp_json, headers: { 'Content-type' => 'application/json' })
  end

  it 'should be able to check against a flat json key/value pair and report ok successfully' do
    json = "{\"health\":\"good\"}"
    stub_with_webmock(json)

    json = CheckJson.new
    json.config[:url] = 'https://example.com:45699/health/check'
    json.config[:key] = 'health'
    json.config[:value] = 'good'

    expect(json).to receive(:ok).with('Valid JSON and key present and correct')
    json.run
  end

  it 'should be able to check against a flat json key/value and send a critical message' do
    json = "{\"health\":\"good\"}"
    stub_with_webmock(json)

    json = CheckJson.new
    json.config[:url] = 'https://example.com:45699/health/check'
    json.config[:key] = 'health'
    json.config[:value] = 'NOT-PRESENT-VALUE!'

    expect(json).to receive(:critical).with('JSON key check failed')
    json.run
  end

  it 'should be able to check against a nested json key/value and report ok successfully' do
    nested_json = "{\"toplevel\":{\"health\":\"good\"}}"
    stub_with_webmock(nested_json)

    json = CheckJson.new
    json.config[:url] = 'https://example.com:45699/health/check'
    json.config[:key] = 'toplevel,health'
    json.config[:value] = 'good'

    expect(json).to receive(:ok).with('Valid JSON and key present and correct')
    json.run
  end

  it 'should be able to check against a nested json key/value and send a critical message' do
    nested_json = "{\"toplevel\":{\"health\":\"good\"}}"
    stub_with_webmock(nested_json)

    json = CheckJson.new
    json.config[:url] = 'https://example.com:45699/health/check'
    json.config[:key] = 'toplevel'
    json.config[:value] = 'WRONG'

    expect(json).to receive(:critical).with('JSON key check failed')
    json.run
  end

  it 'should be able to check against a malformed nested json key/value and send a critical message' do
    nested_json = "{\"toplevel\":{\"health\":\"good\"}}"
    stub_with_webmock(nested_json)

    json = CheckJson.new
    json.config[:url] = 'https://example.com:45699/health/check'
    json.config[:key] = 'no,such,key,path'
    json.config[:value] = 'WRONG'

    expect(json).to receive(:critical).with('JSON key check failed')
    json.run
  end

end
