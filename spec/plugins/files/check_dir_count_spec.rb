#! /usr/bin/env ruby
#
#   check_dir_count_spec
#
# DESCRIPTION:
#   rspec testing to test the functionality of check_dir_count spec
#   in particular the different combination of input options
#
# OUTPUT:
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   rspec
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Inny <mini.inny@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require_relative '../../../plugins/files/check_dir_count'
require 'plugin_stub'

describe DirCount, 'run' do

  include_context :plugin_stub

  ROOTDIR = 'spec/fixtures/plugins/files'

  before(:all) do
    %w[another-sample-1, another-sample-2, another-sample-3, sample-1, sample-2, test-sample].each do |foldername|
      FileUtils.mkdir_p "#{ROOTDIR}/#{foldername}"
    end
  end

  describe '#directory' do
    it 'return unknown if given incorrect path to directory' do
      args = [
        '--dir',
        'incorrect/path',
        '-w',
        '10',
        '-c',
        '20'
      ]
      check_dir = DirCount.new(args)
      expected_output = 'Error listing files in incorrect/path'
      expect(check_dir).to receive('unknown').with(expected_output)
      check_dir.run
    end
  end

  describe '#warning #critical' do
    it 'return ok if given a correct path' do
      args = [
        '--dir',
        ROOTDIR,
        '-w',
        '10',
        '-c',
        '20'
      ]
      check_dir = DirCount.new(args)
      expected_output = 'spec/fixtures/plugins/files has 6 files'
      expect(check_dir).to receive('ok').with(expected_output)
      check_dir.run
    end

    it 'return warning when number of files exceed threshold' do
      args = [
        '--dir',
        ROOTDIR,
        '-w',
        '6',
        '-c',
        '10'
      ]
      check_dir = DirCount.new(args)
      expected_output = 'spec/fixtures/plugins/files has 6 files (threshold: 6)'
      expect(check_dir).to receive('warning').with(expected_output)
      check_dir.run
    end

    it 'return critical when number of files exceed threshold' do
      args = [
        '--dir',
        ROOTDIR,
        '-w',
        '1',
        '-c',
        '2'
      ]

      check_dir = DirCount.new(args)
      expected_output = 'spec/fixtures/plugins/files has 6 files (threshold: 2)'
      expect(check_dir).to receive('critical').with(expected_output)
      check_dir.run
    end
  end

  describe '#file_pattern' do
    it 'return all files with default file pattern' do
      args = [
        '--dir',
        ROOTDIR,
        '-w',
        '10',
        '-c',
        '20'
      ]

      check_dir = DirCount.new(args)
      expected_output = 'spec/fixtures/plugins/files has 6 files'
      expect(check_dir).to receive('ok').with(expected_output)
      check_dir.run
    end

    it 'return 3 matches that matches with another-sample* file_pattern' do
      args = [
        '--dir',
        ROOTDIR,
        '-w',
        '10',
        '-c',
        '20',
        '-p',
        'another-sample*'
      ]

      check_dir = DirCount.new(args)
      expected_output = 'spec/fixtures/plugins/files has 3 files'
      expect(check_dir).to receive('ok').with(expected_output)
      check_dir.run
    end

    it 'return 0 matches when given no-match-* file_pattern' do
      args = [
        '--dir',
        ROOTDIR,
        '-w',
        '10',
        '-c',
        '20',
        '-p',
        'no-mathc-*'
      ]

      check_dir = DirCount.new(args)
      expected_output = 'spec/fixtures/plugins/files has 0 files'
      expect(check_dir).to receive('ok').with(expected_output)
      check_dir.run
    end
  end

  after(:all) do
    FileUtils.rm_rf(ROOTDIR)
  end
end
