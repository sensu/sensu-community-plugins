require 'rbconfig'
require 'ostruct'

module Sensu
  module Extension
    class Check
    end
  end
end

require_relative '../../../extensions/checks/haproxy.rb'
describe Sensu::Extension::Haproxy do
  let(:subject) do
    Sensu::Extension::Haproxy.new
  end
  let(:check) do
    { haproxy: {
      stats_source: 'http://localhost/',
      port: '80',
      missing_ok: true
    } }
  end

  # because of the way csv parses strings, there should be no indentation/spaces before the first character of the line
  # or it will be included in the parsed value.
  let(:stats_good) do
    # rubocop: disable LineLength
    '# pxname,svname,qcur,qmax,scur,smax,slim,stot,bin,bout,dreq,dresp,ereq,econ,eresp,wretr,wredis,status,weight,act,bck,chkfail,chkdown,lastchg,downtime,qlimit,pid,iid,sid,throttle,lbtot,tracked,type,rate,rate_lim,rate_max,check_status,check_code,check_duration,hrsp_1xx,hrsp_2xx,hrsp_3xx,hrsp_4xx,hrsp_5xx,hrsp_other,hanafail,req_rate,req_rate_max,req_tot,cli_abrt,srv_abrt,comp_in,comp_out,comp_byp,comp_rsp,lastsess,
generic-service,FRONTEND,,,0,0,500000,0,0,0,0,0,0,,,,,OPEN,,,,,,,,,1,2,0,,,,0,0,0,0,,,,0,0,0,0,0,0,,0,0,0,,,0,0,0,0,,
generic-service,node-1,0,0,0,0,,0,0,0,,0,,0,0,0,0,UP,1,1,0,6,0,1468949,0,,1,2,1,,0,,2,0,,0,L7OK,200,1,0,0,0,0,0,0,0,,,,0,0,,,,,-1,
generic-service,node-2,0,0,0,0,,0,0,0,,0,,0,0,0,0,UP,1,1,0,0,0,1468949,0,,1,2,2,,0,,2,0,,0,L7OK,200,1,0,0,0,0,0,0,0,,,,0,0,,,,,-1,
generic-service,node-3,0,0,0,0,,0,0,0,,0,,0,0,0,0,UP,1,1,0,0,0,1468949,0,,1,2,3,,0,,2,0,,0,L7OK,200,3,0,0,0,0,0,0,0,,,,0,0,,,,,-1,
generic-service,BACKEND,0,0,0,0,50000,0,0,0,0,0,,0,0,0,0,UP,3,3,0,,0,1468949,0,,1,11,0,,0,,1,0,,0,,,,0,0,0,0,0,0,,,,,0,0,0,0,0,0,-1,'
    # rubocop: enable LineLength
  end

  let(:stats_multiple) do
    '# pxname,svname
generic-service,FRONTEND,
generic-service,node-1,
generic-service,node-2,
generic-service,node-3,
generic-service,BACKEND,
specific-service,FRONTEND,
specific-service,node-4,
specific-service,node-5,
specific-service,node-6,
specific-service,BACKEND,'
  end

  let(:stats_warning) do
    '# pxname,svname, status, slim, scur
generic-service,FRONTEND,UP,0,0
generic-service,node-1,UP,0,0,
generic-service,node-2,UP,0,0,
generic-service,node-3,DN,0,0,
generic-service,BACKEND,0,0,0'
  end

  let(:stats_critical) do
    '# pxname,svname, status, slim, scur
generic-service,FRONTEND,UP,0,0
generic-service,node-1,DN,0,0,
generic-service,node-2,DN,0,0,
generic-service,node-3,DN,0,0,
generic-service,BACKEND,0,0,0'
  end

  describe 'returns name and description' do
    it 'should have sane name' do
      expect(subject.name).to eq('haproxy')
    end
    it 'should have sane description' do
      expect(subject.description).to be_a_kind_of(String)
    end
    it 'should have a definition' do
      expect(subject.definition[:type]).to eq('check')
      expect(subject.definition[:name]).to eq('haproxy')
      expect(subject.definition[:standalone]).to eq(false)
    end
  end

  describe 'default options' do
    let(:opts) { subject.options }
    it 'should contain defaults' do
      expect(opts[:port]).to eq(80)
      expect(opts).to have_key(:path)
      expect(opts).to have_key(:username)
      expect(opts).to have_key(:password)
      expect(opts).to have_key(:warn_percent)
      expect(opts).to have_key(:crit_percent)
      expect(opts).to have_key(:session_crit_percent)
      expect(opts).to have_key(:session_warn_percent)
      expect(opts).to have_key(:all_services)
      expect(opts).to have_key(:missing_ok)
      expect(opts).to have_key(:exact_match)
      expect(opts).to have_key(:service)
    end
  end

  describe 'check required params' do
    before do
      allow(subject).to receive(:acquire_services).and_return({})
    end
    it 'should fail is missing required options' do
      check = {}
      subject.run(check) do |_message, status|
        expect(status).to eq(2)
      end
    end

    it 'should return unknown if no services specified' do
      check[:haproxy][:service] = false
      check[:haproxy][:all_services] = false
      subject.run(check) do |_message, status|
        expect(status).to eq(3)
      end
    end

    it 'should pass with at least required options' do
      subject.run(check) do |_message, status|
        expect(status).to eq(0)
      end
    end

    it 'should fail if no service specified' do
      check[:haproxy][:service] = false
      check[:haproxy][:all_services] = false
      subject.run(check) do |_message, status|
        expect(status).to eq(3)
      end
    end

    it 'should warn if missing services not ok' do
      check[:haproxy][:missing_ok] = false
      subject.run(check) do |_message, status|
        expect(status).to eq(1)
      end
    end
  end

  describe 'run check' do
    it 'should return all ok' do
      expect(subject).to receive(:http_request).and_return(stats_good)
      subject.run(check) do |_message, status|
        expect(status).to eq(0)
      end
    end

    it 'should return a warning' do
      check[:haproxy][:warn_percent] = 65
      expect(subject).to receive(:http_request).and_return(stats_warning)
      subject.run(check) do |_message, status|
        expect(status).to eq(1)
      end
    end

    it 'should return a critical' do
      check[:haproxy][:warn_percent] = 30
      expect(subject).to receive(:http_request).and_return(stats_critical)
      subject.run(check) do |_message, status|
        expect(status).to eq(2)
      end
    end
  end

  describe 'acquire_services' do
    it 'should correctly use socket' do
      check[:haproxy][:stats_source] = '/dev/tcp/localhost/3030'

      allow(File).to receive(:socket?).and_return(true)
      expect(subject).to receive(:socket_request).and_return(stats_good)

      expect(subject.acquire_services).to be_a_kind_of(Array)
    end

    it 'should correctly use http requests' do
      check[:haproxy][:stats_source] = 'http://localhost:8080/'
      expect(subject).to receive(:http_request).and_return(stats_good)
      expect(subject.acquire_services).to be_a_kind_of(Array)
    end

    it 'should use all_services option if enabled' do
      check[:haproxy][:all_services] = true
      test = '#var1,var2
1,2'
      expect(subject).to receive(:http_request).and_return(test)
      output = subject.acquire_services
      expect(output).to be_a_kind_of(Array)
      expect(output).to eq([{ var1: '1', var2: '2' }])
    end

    it 'should filter out service' do
      check[:haproxy][:all_services] = false
      check[:haproxy][:service] = 'specific'
      expect(subject).to receive(:options).at_least(1).and_return(check[:haproxy])
      expect(subject).to receive(:http_request).and_return(stats_multiple)
      output = subject.acquire_services
      expected_output = [
        { pxname: 'specific-service', svname: 'node-4' },
        { pxname: 'specific-service', svname: 'node-5' },
        { pxname: 'specific-service', svname: 'node-6' }
      ]
      expect(output).to eq(expected_output)
    end

    it 'should not match bad name with exact match' do
      check[:haproxy][:all_services] = false
      check[:haproxy][:service] = 'specific'
      check[:haproxy][:exact_match] = true
      expect(subject).to receive(:options).at_least(1).and_return(check[:haproxy])
      expect(subject).to receive(:http_request).and_return(stats_multiple)
      output = subject.acquire_services
      expect(output).to eq([])
    end

    it 'should match service name with exact match' do
      check[:haproxy][:all_services] = false
      check[:haproxy][:service] = 'specific-service'
      check[:haproxy][:exact_match] = true
      expect(subject).to receive(:options).at_least(1).and_return(check[:haproxy])
      expect(subject).to receive(:http_request).and_return(stats_multiple)
      output = subject.acquire_services
      expected_output = [
        { pxname: 'specific-service', svname: 'node-4' },
        { pxname: 'specific-service', svname: 'node-5' },
        { pxname: 'specific-service', svname: 'node-6' }
      ]
      expect(output).to eq(expected_output)
    end
  end

  describe 'http_request' do
    before do
      allow_any_instance_of(Net::HTTP).to receive(:start).and_return(OpenStruct.new(code: 300))
      allow_any_instance_of(Net::HTTP::Get).to receive(:request).and_return(true)
    end
    it 'throws an error on non 200 code' do
      begin
        subject.http_request
      rescue => e
        expect(e).to be_a_kind_of(RuntimeError)
      end
    end

    it 'should return status 3 on http_request error' do
      subject.run(check) do |message, status|
        expect(status).to eq(3)
        expect(message).to include('Failed to fetch from')
      end
    end

  end

end
