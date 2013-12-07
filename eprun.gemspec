$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'eprun/version'

Gem::Specification.new do |s|
  s.name     = "eprun"
  s.version  = ::Eprun::VERSION
  s.authors  = ["Ayumu Nojima (野島 歩)", "Martin J. Dürst"]
  s.email    = ["duerst@it.aoyama.ac.jp"]
  s.homepage = "http://github.com/duerst/eprun"

  s.description = s.summary = "Efficient pure Ruby Unicode normalization."

  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true

  s.require_path = 'lib'

  s.files = Dir["{lib,spec}/**/*", "Gemfile", "History.txt", "LICENSE", "README.md", "Rakefile", "eprun.gemspec"]
end
