require 'rspec/core/rake_task'
require 'rubocop/rake_task'

desc 'Don\'t run Rubocop for unsupported versions'
begin
  if RUBY_VERSION >= '1.9.3'
    args = [:spec, :make_plugins_executable, :rubocop]
  else
    args = [:spec, :make_plugins_executable]
  end
end

Rubocop::RakeTask.new

RSpec::Core::RakeTask.new(:spec) do |r|
  r.pattern = FileList['**/**/*_spec.rb']
end

desc 'Calculate technical debt'
task :calculate_debt do
  `/usr/bin/env ruby scripts/tech_debt.rb`
end

desc 'Make all plugins executable'
task :make_plugins_executable do
  `chmod -R +x /plugins/*`
end

task default: args
