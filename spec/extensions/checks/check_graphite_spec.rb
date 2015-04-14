require 'rbconfig'
require 'ostruct'

module Sensu
  module Extension
    class Check
    end
  end
end

require_relative '../../../extensions/checks/check_graphite.rb'

describe Sensu::Extension::GraphiteCheck do
  let(:subject) do
    Sensu::Extension::GraphiteCheck.new
  end
  let(:check) do
    { check_graphite: {
      server: 'http://localhost/',
      target: 'servers.node.cpu-0'
    } }
  end

  let(:good_raw_data) do
    '[
      {
        "target": "node.cpu",
        "datapoints": [
          [
            1,
            1428611430
          ],
          [
            2,
            1428611440
          ],
          [
            3,
            1428611450
          ]
        ]
      }
    ]'
  end

  let(:good_data) do
    { 'node.cpu' => { 'target' => 'node.cpu', 'data' => [1, 2, 3], 'start' => 1428611430, 'end' => 1428611450, 'step' => 7 } } # rubocop: disable NumericLiterals,LineLength
  end
  let(:decreased_data) do
    { 'node.cpu' => { 'target' => 'node.cpu', 'data' => [1, 2, 3, 4, 5, 4], 'start' => 1428611430, 'end' => 1428611450, 'step' => 7 } } # rubocop: disable NumericLiterals,LineLength
  end

  describe 'returns name and description' do
    it 'should have sane name' do
      expect(subject.name).to eq('check_graphite')
    end
    it 'should have sane description' do
      expect(subject.description).to be_a_kind_of(String)
    end
    it 'should have a definition' do
      expect(subject.definition[:type]).to eq('check')
      expect(subject.definition[:name]).to eq('check_graphite')
      expect(subject.definition[:standalone]).to eq(false)
    end
  end

  describe 'default options' do
    let(:opts) { subject.options }
    it 'should contain defaults' do
      expect(opts).to have_key(:target)
      expect(opts).to have_key(:server)
      expect(opts).to have_key(:username)
      expect(opts).to have_key(:password)
      expect(opts).to have_key(:passfile)
      expect(opts).to have_key(:warning)
      expect(opts).to have_key(:critical)
      expect(opts).to have_key(:reset_on_decrease)
      expect(opts).to have_key(:name)
      expect(opts).to have_key(:allowed_graphite_age)
      expect(opts).to have_key(:hostname_sub)
      expect(opts).to have_key(:from)
      expect(opts).to have_key(:below)
      expect(opts).to have_key(:no_ssl_verify)
    end
  end

  describe 'check required params' do
    it 'should fail is missing required options' do
      check = {}
      subject.run(check) do |message, status|
        expect(status).to eq(2)
        expect(message).to include('MISSING')
      end
    end
    it 'should fail is missing a required option' do
      check = { check_graphite: {
        target: 'servers.node.cpu-0'
      } }
      subject.run(check) do |message, status|
        expect(status).to eq(2)
        expect(message).to include('MISSING')
      end
    end
  end

  describe 'retrieve_data' do
    before do
    end
    it 'should raise on empty data' do
      allow(subject).to receive(:open).and_return(OpenStruct.new(gets: '[]'))
      begin
        subject.retrieve_data
      rescue => e
        expect(e.message).to include('Empty data')
      end
    end

    it 'should delete nil data' do
      nill_data = '[
      {
        "target": "servers.node1.cpu-0.cpu-idle",
        "datapoints": [
          [
            null,
            1428611430
          ],
          [
            null,
            1428611440
          ],
          [
            null,
            1428611450
          ] ]
      } ]'
      allow(subject).to receive(:open).and_return(OpenStruct.new(gets: nill_data))

      output = subject.retrieve_data
      expect(output).to eq({})
    end

    it 'should parse data' do
      allow(subject).to receive(:open).and_return(OpenStruct.new(gets: good_raw_data))
      output = subject.retrieve_data
      expect(output).to eq(good_data)
    end
    it 'should prepend server name with http if missing' do

    end

  end

  describe 'run check' do

    before do
      allow(subject).to receive(:check_age)
    end

    it 'should return all ok' do
      allow(subject).to receive(:retrieve_data).and_return(good_data)
      check[:check_graphite][:warning] = 5
      check[:check_graphite][:critical] = 10
      subject.run(check) do |message, status|
        expect(status).to eq(0)
        expect(message).to include('value okay')
      end
    end

    it 'should return a warning' do
      allow(subject).to receive(:retrieve_data).and_return(good_data)
      check[:check_graphite][:warning] = 1
      subject.run(check) do |message, status|
        expect(message).to include('warning')
        expect(status).to eq(1)
      end
    end

    it 'should return a critical' do
      allow(subject).to receive(:retrieve_data).and_return(good_data)
      check[:check_graphite][:critical] = 1
      subject.run(check) do |message, status|
        expect(message).to include('critical')
        expect(status).to eq(2)
      end
    end

    it 'should pass if value above threshold but decreased' do
      check[:check_graphite][:reset_on_decrease] = 2
      allow(subject).to receive(:retrieve_data).and_return(decreased_data)
      check[:check_graphite][:critical] = 1
      subject.run(check) do |message, status|
        expect(message).to include('okay')
        expect(status).to eq(0)
      end

    end

  end

  describe 'outdated data' do

    it 'should fail on outdated data' do
      allow(subject).to receive(:retrieve_data).and_return(good_data)
      subject.run(check) do |message, status|
        expect(message).to include('data age is past allowed')
        expect(status).to eq(3)
      end
    end

  end

end
