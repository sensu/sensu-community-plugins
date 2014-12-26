#! /usr/bin/env ruby
#
#   check-cpu_spec
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
# LICENSE:
#   Copyright 2014 Yieldbot. <devops@yieldbot.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require_relative '../../../plugins/system/check-cpu'
require_relative '../../../spec_helper'

def cpu_output
  File.open('spec/fixtures/plugins/system/cpu_test.txt', 'r')
end

describe CheckCPU, 'run' do

  it '' do
  end

  it '' do
  end

  it '' do
  end

end
