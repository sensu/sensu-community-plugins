require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec) do |r|
  r.pattern = FileList['**/**/*_spec.rb']
end

Rubocop::RakeTask.new

task :default => [:spec, :rubocop]

desc "Calculate technical debt"
task :calculate_debt do
  `ruby scripts/tech_debt.rb`
end
