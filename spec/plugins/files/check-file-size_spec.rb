#! /usr/bin/env ruby
#
#   check-file-size_spec.rb
#
# DESCRIPTION:
#   Run rspec tests against check-file-size.rb Sensu check
#
# OUTPUT:
#   rspec output
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
#   Copyright 2015 Jayson Sperling <jayson.sperling@sendgrid.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require_relative '../../../plugins/files/check-file-size'
require_relative '../../../spec_helper'

describe CheckFileSize, 'run' do

  check_file_size = nil

  before(:each) do
    check_file_size = CheckFileSize.new
  end

  describe 'using no parameters' do
    it 'will fail'
  end

  describe '#ignore-missing' do
    it 'returns CRITICAL if file is missing'
    it 'returns OK if file is missing and --ignore-missing is used'
  end

  describe '#warning' do
    it 'returns OK if file size is under --warn value'
    it 'returns WARNING if file size is over --warn value'
  end

  describe '#critical' do
    it 'returns OK if file size is under --critical value'
    it 'returns CRITICAL if file size is over --critical value'
  end

end
