#!/usr/bin/env ruby
#  encoding: UTF-8
#  check-test-suite
#
#  DESCRIPTION:
#    This plugin attempts to run rspec and return the results of the run to the handler.
#
#    When a run begins, it creates a file cache that it will reference on the next run to
#      prevent false positives from being returned to the handler. If the run fails a particular
#      codebase twice, then it will return critical to the handler, not on the first fail.
#
#  OUTPUT:
#    plain text
#
#  PLATFORMS:
#    Linux
#
#  DEPENDENCIES:
#    gem: sensu-plugin
#    gem: json
#    gem: rspec
#    gem: fileutils
#
#  USAGE:
#    sudo /opt/sensu/embedded/bin/ruby /etc/sensu/plugins/check-test-suite.rb -p location_of_codebase1,location_of_codebase2,location_of_codebase3 -b /home/#{ deploy_user }/.rvm/rubies/ruby-2.2.0/bin/ruby
#
#  NOTES:
#    location_of_codebase should be a full path
#    sudo is preferred but may not be necessary (depending on your test suite, the sensu user may not have write permissions to the directories where the code is to deal with things like coverage gem)
#    The codebases must be managed through git to be effective, the check relies on being able to find the commits in the filesystem.
#
#  LICENSE:
#    Louis Alridge louis@socialcentiv.com
#    Released under the same terms as Sensu (the MIT license); see LICENSE
#    for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'json'
require 'rspec'
require 'fileutils'
require 'sensu-plugin/check/cli'

class CheckTestSuite < Sensu::Plugin::Check::CLI

  option :paths,
         :description => "Paths to run the tests, comma delimited",
         :short => '-p PATHS',
         :long => '--path PATHS'

  option :ruby_bin,
         short: '-b ruby',
         long: '--ruby-bin ruby',
         default: 'ruby'

  option :environment_variables,
         short: '-e aws_access_key_id=XXX',
         long: '--env-var aws_access_key_id=XXX',
         required: false

  option :test_suite,
         :description => "Test suite to test against, defaults to rspec",
         :short => '-t SUITE',
         :long => '--test-suite SUITE',
         :default => 'rspec'

  option :suite_arguments,
         :description => "Optional args to pass to rspec, defaults to --fail-fast. Enclose args in quotes.",
         :short => '-a "RSPEC_ARGS"',
         :long => '--args "RSPEC_ARGS"',
         :default => '--fail-fast'

  option :gem_home,
         :description => "",
         :short => "-d GEM_HOME",
         :long => "--gem-home GEM_HOME",
         :default => "vendor/bundle"

  def initialize_file_cache branch, commit
    commit_file_directory = "/var/log/sensu/check-test-suite-#{ branch }"

    FileUtils.mkdir_p commit_file_directory

    write_file_cache_message (commit_file_directory + '/' + commit), 'verified'
  end

  def write_file_cache_message location, message
    if !File.exists?(location)
      File.open( location, "w") { |f| f.write(message) }
    else
      File.open( location, 'a') { |f| f.puts(message) }
    end
  end

  def run
    begin
      full_start       = Time.now
      tests            = {}
      successful_tests = {}

      final_gem_home = config[:gem_home]

      config[:paths].split(',').each do |path|
        start       = Time.now
        tests[path] = {}

        tests[path]['commit']     = `/bin/readlink #{ path }`.split('/').last.chomp.strip
        tests[path]['branch']     = `cd #{ path } && /usr/bin/git branch -r --contains #{ tests[path]['commit'] }`.split("\n").last.chomp.strip.split('origin/').last

        initialize_file_cache tests[path]['branch'], tests[path]['commit']

        commit_file = "/var/log/sensu/check-test-suite-#{ tests[path]['branch'] }/#{ tests[path]['commit'] }"

        next if File.exist?( commit_file ) && File.read( commit_file ).include?('successful')

        if config[:gem_home] == 'vendor/bundle'
          target_ruby = ""
          target_rubies = Dir.entries("#{ path }/#{ config[:gem_home] }/ruby").select {|item| item =~ /(\d+\.\d+\.\d+)/}

          target_rubies.each do |ruby|
            target_rubies.each do |other_ruby|
              target_ruby = if ruby != other_ruby
                              ruby if Gem::Version.new(ruby) > Gem::Version.new(other_ruby)
                            elsif target_rubies.count == 1
                              ruby
                            end
            end
          end

          final_gem_home = `/bin/readlink #{ path }`.chomp.strip + "/#{ config[:gem_home] }/ruby/#{ target_ruby }"
        end

        ENV['GEM_HOME']  = final_gem_home

        tests[path]['test_suite_out']  = `cd #{ path }; #{ config[:environment_variables] } #{config[:ruby_bin]} -S #{ config[:test_suite] } #{ config[:suite_arguments] } --failure-exit-code 2`

        tests[path]['runtime']    = Time.now - start
        tests[path]['exitstatus'] = $?.exitstatus
        tests[path]['commit']     = `/bin/readlink #{ path }`.split('/').last
        tests[path]['branch']     = `cd #{ path } && /usr/bin/git branch -r --contains #{ tests[path]['commit'] }`.split("\n").last.chomp.strip.split('origin/').last
        tests[path]['metadata']   = `cd #{ path } && /usr/bin/git show #{ tests[path]['commit'] }`

        case tests[path]['exitstatus']
        when 2
          test_suite_lines = tests[path]['test_suite_out'].split("\n")
          test_suite_out_fail_line = test_suite_lines.index(test_suite_lines.select { |line| line.include?('Failures:') }.first)

          write_file_cache_message commit_file, 'failure'

          #to eliminate false positives, we run a failing suite twice before sending the response
          next if File.read( commit_file ).scan(/failure/).count < 2
          
          critical "CRITICAL! Rspec returned failed tests for #{ tests[path]['branch'] }!\n\n#{ tests[path]['metadata'] }#{ test_suite_lines[test_suite_out_fail_line..(test_suite_lines.count)].join("\n") }\n\nError'd in #{ tests[path]['runtime'] } seconds."
        when 0
          successful_tests[path] = tests[path]

          write_file_cache_message commit_file, 'successful'

          ok "OK! Rspec returned no failed tests for #{ tests[path]['branch'] }.\n\n#{ tests[path]['metadata'] }\n\nCompleted in #{ tests[path]['runtime'] }" if config[:paths].split(',').length == 1
        else
          unknown "Strange exit status detected for rspec on #{ tests[path]['branch'] }.\n\n#{ tests[path]['test_suite_out'] }"
        end
      end

      successful_branches = []

      successful_tests.each_pair {|key,hash| successful_branches << hash['branch'] }

      ok "OK! Rspec returned no failed tests for #{ successful_branches.join(', ') }.\nCompleted in #{ full_start - Time.now } seconds."
    rescue StandardError => e
      critical "Error message: #{e}\n#{e.backtrace.join("\n")}"
    end
  end
end
