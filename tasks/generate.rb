# coding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

require 'erb'
require 'pathname'

module Eprun
  class Template

    def initialize(template, attrs = {})
      @template = template
      attrs.each_pair do |attr, val|
        attr_reader attr
        instance_variable_set(:"@#{attr}", val)
      end
    end

    def render
      ERB.new(@template).result(binding)
    end

  end
end

class Integer
  def to_UTF8()
    [self].pack("U*").bytes.to_a.map { |s| "\\" + s.to_s(8) }.join
    # if self>0xFFFF
    #   "\\u{#{to_s(16).upcase}}"
    # elsif CombiningClass[self] or self=='\\'.ord or self=='"'.ord
    #   "\\u#{to_s(16).upcase.rjust(4, '0')}"
    # else
    #   chr Encoding::UTF_8
    # end
  end
end

class Array
  def line_slice (new_line) # joins items, 16 items per line
    each_slice(16).collect(&:join).join new_line
  end
  
  def to_UTF8()  collect(&:to_UTF8).join  end
  
  def to_regexp_chars # converts an array of Integers to character ranges
    sort.inject([]) do |ranges, value|
      if ranges.last and ranges.last[1]+1>=value
        ranges.last[1] = value
        ranges
      else
        ranges << [value, value]
      end
    end.collect do |first, last|
      case last-first
      when 0
        first.to_UTF8
      when 1
        first.to_UTF8 + last.to_UTF8
      else
        first.to_UTF8 + '-' + last.to_UTF8
      end
    end.line_slice "\" +\n    \""
  end
end

class Hash
  def to_hash_string
    collect do |key, value|
      "#{key.inspect}=>#{value.inspect}, "
    end.line_slice "\n    "
  end
end

root_dir = Pathname.new(File.join(File.dirname(File.dirname(__FILE__))))

# read the file 'CompositionExclusions.txt'
composition_exclusions = IO.readlines(root_dir.join("data/CompositionExclusions.txt").to_s).
  select { |line| line =~ /^[A-Z0-9]{4,5}/ }.
  collect { |line| line.split(' ').first.hex }

decomposition_table = {}
kompatible_table = {}
CombiningClass = {}  # constant to allow use in Integer#to_UTF8

# read the file 'UnicodeData.txt'
IO.foreach(root_dir.join("data/UnicodeData.txt").to_s) do |line|
  codepoint, name, _2, char_class, _4, decomposition, *_rest = line.split(";")
  
  case decomposition
  when /^[0-9A-F]/
    decomposition_table[codepoint.hex] = decomposition.split(' ').collect(&:hex)
  when /^</
    kompatible_table[codepoint.hex] = decomposition.split(' ').drop(1).collect(&:hex)
  end
  CombiningClass[codepoint.hex] = char_class.to_i if char_class != "0"
  
  if name=~/(First|Last)>$/ and (char_class!="0" or decomposition!="")
    warn "Unexpected: Character range with data relevant to normalization!"
  end
end

# calculate compositions from decompositions
composition_table = decomposition_table.reject do |character, decomposition|
  composition_exclusions.member? character or # predefined composition exclusion
    decomposition.length<=1 or                # Singleton Decomposition
    CombiningClass[character] or              # character is not a Starter
    CombiningClass[decomposition.first]       # decomposition begins with a character that is not a Starter
end.invert

# recalculate composition_exclusions
composition_exclusions = decomposition_table.keys - composition_table.values

accent_array = CombiningClass.keys + composition_table.keys.collect(&:last)

composition_starters = composition_table.keys.collect(&:first)

hangul_no_trailing = 0xAC00.step(0xD7A3, 28).to_a

# expand decomposition table values
decomposition_table.each do |key, value|
  position = 0
  while position < value.length
    if decomposition = decomposition_table[value[position]]
      decomposition_table[key] = value = value.dup # avoid overwriting composition_table key
      value[position, 1] = decomposition
    else
      position += 1
    end
  end
end

# deal with relationship between canonical and kompatibility decompositions
decomposition_table.each do |key, value|
  value = value.dup
  expanded = false
  position = 0
  while position < value.length
    if decomposition = kompatible_table[value[position]]
      value[position, 1] = decomposition
      expanded = true
    else
      position += 1
    end
  end
  kompatible_table[key] = value if expanded
end

class_table_str = CombiningClass.collect do |key, value|
  "#{key.inspect}=>#{value.inspect}, "
end.line_slice "\n    "

# generate normalization tables file
# open("normalize_tables.rb", "w").print

attrs = {
  :accent_array => accent_array.to_regexp_chars
}

template = Eprun::Template.new(
  File.read(root_dir.join("tasks/template.rb.erb").to_s), attrs
)

File.open(root_dir.join("tasks/tables.rb").to_s) do |f|
  f.write(template.render)
end
