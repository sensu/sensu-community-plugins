require 'rspec'

RSpec.configure do |config|

  config.order = :random
  config.before(:all) do
    config.fail_fast = true

    # #YELLOW
    class Sensu::Plugin::Check::CLI # rubocop:disable Style/ClassAndModuleChildren
      Sensu::Plugin::EXIT_CODES.each do |status, _code|
        define_method(status.downcase) do |*_args|
          # no output
          # no exit
        end
      end
    end

  end

end
