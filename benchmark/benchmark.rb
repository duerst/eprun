# coding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

if self.class.const_defined? :Encoding
  Encoding.default_external = 'utf-8'
  require '../lib/string_normalize'
end

require 'benchmark'

begin
  require "unicode_utils/nfc"
  require "unicode_utils/nfkd"
  require "unicode_utils/nfkc"
  require "unicode_utils/canonical_decomposition"
rescue LoadError
end

begin
  require 'twitter_cldr'
rescue LoadError
end

begin
  require 'active_support/multibyte/chars'
rescue LoadError
end

begin
  require 'unicode'
rescue LoadError
end

def benchmark_test(test_data)
  puts "________________ #{test_data.name} (#{test_data.text.length} characters, #{test_data.text.bytes.to_a.length} bytes) ________________"
  Benchmark.bm(6) do |x|
    if String.method_defined? :encode
      puts "Fast normalization using eprun (100 times)"
      x.report("NFD:")  { 100.times { test_data.text.normalize :nfd  } }
      x.report("NFKD:") { 100.times { test_data.text.normalize :nfkd } }
      x.report("NFC:")  { 100.times { test_data.text.normalize :nfc  } }
      x.report("NFKC:") { 100.times { test_data.text.normalize :nfkc } }
      puts "Hash size: NFD #{Normalize::NF_HASH_D.size}, NFC #{Normalize::NF_HASH_C.size}, K #{Normalize::NF_HASH_K.size}"
    end
    if self.class.const_defined? :UnicodeUtils
      puts
      puts "Using unicode_utils gem (100 times)"
      x.report("NFD:")  { 100.times { UnicodeUtils.canonical_decomposition test_data.text } } # nfd not available
      x.report("NFKD:") { 100.times { UnicodeUtils.nfkd test_data.text } }
      x.report("NFC:")  { 100.times { UnicodeUtils.nfc  test_data.text } }
      x.report("NFKC:") { 100.times { UnicodeUtils.nfkc test_data.text } }
    end
    if String.method_defined? :localize
      puts
      puts "Using twitter_cldr gem (a single time)"
      x.report("NFD:")  { TwitterCldr::Normalization::NFD.normalize  test_data.text }
      x.report("NFKD:") { TwitterCldr::Normalization::NFKD.normalize test_data.text }
      x.report("NFC:")  { TwitterCldr::Normalization::NFC.normalize  test_data.text }
      x.report("NFKC:") { TwitterCldr::Normalization::NFKC.normalize test_data.text }
    end
    if self.class.const_defined? :ActiveSupport
      puts
      puts "Using ActiveSupport::Multibyte::Chars (10 times)"
      x.report("NFD:")  { 10.times { ActiveSupport::Multibyte::Chars.new(test_data.text).normalize :d  } }
      x.report("NFKD:") { 10.times { ActiveSupport::Multibyte::Chars.new(test_data.text).normalize :kd } }
      x.report("NFC:")  { 10.times { ActiveSupport::Multibyte::Chars.new(test_data.text).normalize :c  } }
      x.report("NFKC:") { 10.times { ActiveSupport::Multibyte::Chars.new(test_data.text).normalize :kc } }
    end
    if self.class.const_defined? :Unicode
      puts
      puts "Using unicode gem (native code, 100 times)"
      x.report("NFD:")  { 100.times { Unicode::normalize_D  test_data.text } }
      x.report("NFKD:") { 100.times { Unicode::normalize_KD test_data.text } }
      x.report("NFC:")  { 100.times { Unicode::normalize_C  test_data.text } }
      x.report("NFKC:") { 100.times { Unicode::normalize_KC test_data.text } }
    end
  end
  puts
end


Language = Struct.new :name, :text

languages = Dir.glob("*_.txt").collect do |filename|
  Language.new(filename[0..-6], IO.read(filename))
end

languages.each { |language| benchmark_test language }
