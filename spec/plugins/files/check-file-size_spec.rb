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

describe CheckFileSize do

  it 'will fail with no parameters' do
  end

  it 'returns CRITICAL if file is missing' do
  end

  it 'returns OK if file is missing and --ignore-missing is used' do
  end

  it 'returns OK if file size is under --warn value' do
  end

  it 'returns WARNING if file size is over --warn value' do
  end

  it 'returns OK if file size is under --critical value' do
  end

  it 'returns CRITICAL if file size is over --critical value' do
  end

end
