# encoding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

require 'rspec'
require 'eprun'
require 'pry-nav'

RSpec.configure do |config|
  config.mock_with :rr
end

Eprun.enable_core_extensions!

unless self.class.const_defined?(:Enumerator)
  module Enumerable
    def with_index
      index = 0
      map do |item|
        ret = yield(item, index)
        index += 1
        ret
      end
    end
  end
end
