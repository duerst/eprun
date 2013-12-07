# encoding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

require 'erb'

class ErbTemplate

  def initialize(template, attrs = {})
    @template = template
    @context = Class.new do
      attrs.each_pair do |attr, val|
        define_method(attr) { val }
      end
    end.new
  end

  def render
    ERB.new(@template).result(@context.send(:binding))
  end

end