require 'rspec'

RSpec.configure do |config|

  config.order = :random
  config.before(:all) do
  config.fail_fast = true

    class Sensu::Plugin::Check::CLI # rubocop:disable IndentationConsistency

      Sensu::Plugin::EXIT_CODES.each do |status, code|
        define_method(status.downcase) do |*args|
          # no output
          # no exit
        end
      end

    end

  end

end
