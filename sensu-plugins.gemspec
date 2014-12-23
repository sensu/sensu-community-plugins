require 'date'
Gem::Specification.new do |gem|
  gem.name                  = 'sensu-community-plugins'
  gem.authors               = ['Sonian, Inc. and contributors']
  gem.email                 = '<support@sensuapp.org>'
  gem.homepage              = 'https://github.com/sensu/sensu-community-plugins'
  gem.license               = 'MIT'
  gem.summary               = ' Sensu community plugins for checks, handlers, & mutators '
  gem.description           = ' Sensu community plugins for checks, handlers, & mutators '
  gem.version               = '0.0.0'
  gem.date                  = Date.today.to_s
  gem.platform              = Gem::Platform::RUBY

  gem.files                 = Dir['Rakefile', '{plugins,extensions,handlers,mutators,lib,spec,scripts}/**/*', 'README*', 'LICENSE*', 'CONTRIB*', 'CHANGELOG*']

  gem.add_dependency 'sensu-plugin', '1.1.0'
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency
  # gem.add_dependency

  gem.add_development_dependency 'bundler',         '~> 1.3'
  gem.add_development_dependency 'rubocop', '~> 0.17.0'
  gem.add_development_dependency 'rake'
  # gem.add_development_dependency 'coveralls',       '~> 0.6.7'
  # gem.add_development_dependency 'guard',           '~> 2.2.3'
  # gem.add_development_dependency 'guard-bundler',   '~> 2.0.0'
  # gem.add_development_dependency 'guard-rspec',     '~> 4.0'
  # gem.add_development_dependency 'guard-cucumber',  '~> 1.4'
  # gem.add_development_dependency 'guard-rubocop',   '~> 1.0'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rspec-mocks'
  # gem.add_development_dependency 'ruby_gntp',       '~> 0.3.4'
  # gem.add_development_dependency 'simplecov',       '~> 0.7.1'
  # gem.add_development_dependency 'yard',            '~> 0.8'
end

# ast (2.0.0)
# diff-lcs (1.2.5)
# json (1.8.1)
# mixlib-cli (1.5.0)
# parser (2.1.9)
# ast (>= 1.1, < 3.0)
# slop (~> 3.4, >= 3.4.5)
# powerpack (0.0.9)
# rainbow (1.99.2)
# rake (10.4.2)
# rspec (3.0.0)
# rspec-core (~> 3.0.0)
# rspec-expectations (~> 3.0.0)
# rspec-mocks (~> 3.0.0)
# rspec-core (3.0.4)
# rspec-support (~> 3.0.0)
# rspec-expectations (3.0.4)
# diff-lcs (>= 1.2.0, < 2.0)
# rspec-support (~> 3.0.0)
# rspec-mocks (3.0.4)
# rspec-support (~> 3.0.0)
# rspec-support (3.0.4)
# rubocop (0.17.0)
# json (~> 1.8)
# parser (~> 2.1.3)
# powerpack (~> 0.0.6)
# rainbow (~> 1.99.1)
# sensu-plugin (1.1.0)
# json
# mixlib-cli (>= 1.1.0)
# slop (3.6.0)
#
# PLATFORMS
# ruby
#
# DEPENDENCIES
# rake
# rspec (~> 3.0.0)
# rubocop (~> 0.17.0)
# sensu-plugin (= 1.1.0)
