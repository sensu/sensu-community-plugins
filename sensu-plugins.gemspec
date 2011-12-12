require File.expand_path(File.dirname(__FILE__)) + '/lib/sensu/plugins'

Gem::Specification.new do |s|
  s.name          = 'sensu-plugins'
  s.version       = Sensu::Plugins::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ['Decklin Foster']
  s.email         = ['decklin@red-bean.com']
  s.homepage      = 'https://github.com/sonian/sensu-plugins'
  s.summary       = 'Sensu Plugins'
  s.description   = 'Plugins and helper libraries for Sensu, a monitoring framework'
  s.license       = 'MIT'
  s.has_rdoc      = false
  s.require_paths = ['lib']
  s.files         = `git ls-files -- lib handlers plugins`.split("\n")
  s.executables   = `git ls-files -- bin`.split("\n").map {|f| File.basename(f) }
end
