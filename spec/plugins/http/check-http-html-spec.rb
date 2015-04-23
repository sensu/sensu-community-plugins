#! /usr/bin/env ruby
#
#   check-http-html-spec
#
# DESCRIPTION: Tests for the check-http-html sensu plugin
#
# OUTPUT:
#
# PLATFORMS:
#
# DEPENDENCIES:
#   gem: check-http-html
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Alexis Bazinet-Deschamps <alexis.bazinet@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require_relative '../../../plugins/http/check-http-html'
require_relative '../../../spec_helper'

require 'webmock/rspec'

EXAMPLE_URL = 'http://example.com:45699/example'

describe CheckHtml, 'run' do
  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  def base_stub_headers
    { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Ruby' }
  end

  def stub_with_webmock(resp_html)
    stub_request(:get, EXAMPLE_URL)
      .with(headers: base_stub_headers)
      .to_return(status: 200, body: resp_html, headers: { 'Content-type' => 'application/html' })
  end

  def html_check
    check = CheckHtml.new
    check.config[:url] = EXAMPLE_URL
    check
  end

  it 'reports ok for html response' do
    stub_with_webmock('<!doctype html><title></title>')

    check = html_check

    expect(check).to receive(:ok).with('Html received')
    check.run
  end

  it 'reports failure for malformed html' do
    stub_with_webmock('<!doctype html')

    check = html_check
    check.config[:validate] = true

    expect(check).to receive(:critical).with('Malformed html response')
    check.run
  end

  it 'reports ok for malformed html without validation' do
    stub_with_webmock('<!doctype html')

    check = html_check

    expect(check).to receive(:ok).with('Html received')
    check.run
  end

  it 'reports failure for malformed html with validation' do
    stub_with_webmock('<!doctype html')

    check = html_check
    check.config[:validate] = true

    expect(check).to receive(:critical).with('Malformed html response')
    check.run
  end

  it 'follows redirects' do
    stub_request(:get, EXAMPLE_URL + '/redirect')
      .with(headers: base_stub_headers)
      .to_return(status: 302, headers: { 'Location' => EXAMPLE_URL })

    stub_with_webmock('<!doctype html><title></title>')

    check = html_check
    check.config[:url] = EXAMPLE_URL + '/redirect'

    expect(check).to receive(:ok).with('Html received')
    check.run
  end

  it 'reports ok for an xpath match against the html' do
    stub_with_webmock('<!doctype html><title></title>')

    check = html_check
    check.config[:xpath] = '//title'

    expect(check).to receive(:ok).with('Xpath match')
    check.run
  end

  it 'reports failure for an xpath miss against the html' do
    stub_with_webmock('<!doctype html><title></title>')

    check = html_check
    check.config[:xpath] = '//body'

    expect(check).to receive(:critical).with('Xpath miss')
    check.run
  end

  it 'reports ok for pattern matching against xpath results' do
    stub_with_webmock('<!doctype html><title>content</title>')

    check = html_check
    check.config[:xpath] = '//title/text()'
    check.config[:regex] = 'content'

    expect(check).to receive(:ok).with('Pattern match against the xpath results')
    check.run
  end

  it 'reports failure for patterns that miss against xpath results' do
    stub_with_webmock('<!doctype html><title>content</title>')

    check = html_check
    check.config[:xpath] = '//title/text()'
    check.config[:regex] = 'NOMATCH'

    expect(check).to receive(:critical).with(['content'])
    check.run
  end
end
