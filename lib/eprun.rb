# encoding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

if self.class.const_defined?(:Encoding)
  Encoding.default_external = 'utf-8'
  Encoding.default_internal = 'utf-8'
end

$KCODE = 'utf-8' unless RUBY_VERSION >= '1.9.0'

require 'eprun/tables'
require 'eprun/normalizer'
require 'eprun/core_ext/string'
