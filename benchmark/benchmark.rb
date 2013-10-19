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

def benchmark_test(test_data)
  puts "_____________________________ #{test_data.name} ____________________________________"
  Benchmark.bm(6) do |x|
    if String.method_defined? :encode
      puts "Fast Normalization using gsub and hash (100 times)"
      nfd_time = x.report("NFD:")   { 100.times { test_data.text.normalize(:nfd) } }
      nfkd_time = x.report("NFKD:") { 100.times { test_data.text.normalize(:nfkd) } }
      nfc_time = x.report("NFC:")   { 100.times { test_data.text.normalize(:nfc) } }
      nfkc_time = x.report("NFKC:") { 100.times { test_data.text.normalize(:nfkc) } }
      puts "Hash size: NFD #{Normalize::NF_HASH_D.size}, NFC #{Normalize::NF_HASH_C.size}, K #{Normalize::NF_HASH_K.size}"
    end
    if self.class.const_defined? :UnicodeUtils
      puts
      puts "Using unicode_utils gem (100 times)"
      utils_nfd_time = x.report("NFD:")   { 100.times { UnicodeUtils.canonical_decomposition(test_data.text) } }
      utils_nfkd_time = x.report("NFKD:") { 100.times { UnicodeUtils.nfkd(test_data.text) } }
      utils_nfc_time = x.report("NFC:")   { 100.times { UnicodeUtils.nfc(test_data.text) } }
      utils_nfkc_time = x.report("NFKC:") { 100.times { UnicodeUtils.nfkc(test_data.text) } }
    end
    if String.method_defined? :localize
      puts
      puts "Using twitter_cldr gem (a single time)"
      twitter_cldr_nfd_time = x.report("NFD:")   { test_data.text.localize.normalize(:using => :NFD)}
      twitter_cldr_nfkd_time = x.report("NFKD:") { test_data.text.localize.normalize(:using => :NFKD)}
      twitter_cldrs_nfc_time = x.report("NFC:")  { test_data.text.localize.normalize(:using => :NFC)}
      twitter_cldr_nfkc_time = x.report("NFKC:") { test_data.text.localize.normalize(:using => :NFKC)}
    end
  end
  puts
end


Language = Struct.new :name, :text

languages = Dir.glob("*_.txt").collect do |filename|
  Language.new(filename[0..-6], IO.read(filename))
end

languages.each { |language| benchmark_test language }
