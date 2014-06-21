require_relative 'check-dns'
require_relative '../../spec_helper'

describe DNS, 'run' do

  it 'returns unknown if there is no domain specified' do
    dns = DNS.new
    dns.should_receive('unknown')
    dns.run
  end

  it 'returns ok if entries are resolved' do
    dns = DNS.new
    dns.config[:domain] = 'www.google.com'
    dns.should_receive('resolve_domain') {['a']}
    dns.should_receive('ok')
    dns.run
  end

  it 'returns ok if specifed entry is included' do
    dns = DNS.new
    dns.config[:domain] = 'www.google.com'
    dns.config[:result] = '1.2.3.4'
    dns.should_receive('resolve_domain') {['1.2.3.4']}
    dns.should_receive('ok')
    dns.run
  end

  it 'returns critical if specifed entry is not included' do
    dns = DNS.new
    dns.config[:domain] = 'www.google.com'
    dns.config[:result] = '1.2.3.4'
    dns.should_receive('resolve_domain') {['4.3.2.1']}
    dns.should_receive('critical')
    dns.run
  end

  it 'returns critical without records' do
    dns = DNS.new
    dns.config[:domain] = 'www.google.com'
    dns.should_receive('resolve_domain') {[]}
    dns.should_receive('critical')
    dns.run
  end

  it 'returns warning if specified' do
    dns = DNS.new
    dns.config[:domain] = 'www.google.com'
    dns.config[:warn_only] = true
    dns.should_receive('resolve_domain') {[]}
    dns.should_receive('warning')
    dns.run
  end

end
