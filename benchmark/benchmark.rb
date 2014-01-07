# encoding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

$KCODE = 'utf-8' unless RUBY_VERSION >= '1.9.0'

require 'eprun'
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

begin
  require 'unf'
rescue LoadError
end

module EprunTasks
  class Benchmarks

    Language = Struct.new(:name, :test_data)

    attr_reader :data_dir

    def initialize(data_dir)
      @data_dir = data_dir
    end

    def all_languages
      @languages ||= Dir.glob(File.join(data_dir, "*_.txt")).collect do |filename|
        Language.new(File.basename(filename[0..-6]), IO.read(filename))
      end
    end

    def run(languages = all_languages)
      languages.each { |language| run_test_for(language) }
    end

    protected

    def run_test_for(language)
      puts "________________ #{language.name} (#{language.test_data.unpack("U*").size} characters, #{language.test_data.bytes.to_a.length} bytes) ________________"
      Benchmark.bm(6) do |x|
        puts "Fast normalization using eprun (100 times)"
        x.report("NFD:")  { 100.times { language.test_data.normalize :nfd  } }
        x.report("NFKD:") { 100.times { language.test_data.normalize :nfkd } }
        x.report("NFC:")  { 100.times { language.test_data.normalize :nfc  } }
        x.report("NFKC:") { 100.times { language.test_data.normalize :nfkc } }
        puts "Hash size: NFD #{Eprun.nf_hash_d.size}, NFC #{Eprun.nf_hash_c.size}, K #{Eprun.nf_hash_k.size}"

        # if self.class.const_defined?(:UNF)
          puts
          puts "Using unf gem (100 times)"
          normalizer = UNF::Normalizer.instance
          x.report("NFD:")  { 100.times { normalizer.normalize(language.test_data, :nfd) } }
          x.report("NFKD:") { 100.times { normalizer.normalize(language.test_data, :nfkd) } }
          x.report("NFC:")  { 100.times { normalizer.normalize(language.test_data, :nfc) } }
          x.report("NFKC:") { 100.times { normalizer.normalize(language.test_data, :nfkc) } }
        # end

        if self.class.const_defined?(:UnicodeUtils)
          puts
          puts "Using unicode_utils gem (100 times)"
          x.report("NFD:")  { 100.times { UnicodeUtils.canonical_decomposition language.test_data } } # nfd not available
          x.report("NFKD:") { 100.times { UnicodeUtils.nfkd language.test_data } }
          x.report("NFC:")  { 100.times { UnicodeUtils.nfc  language.test_data } }
          x.report("NFKC:") { 100.times { UnicodeUtils.nfkc language.test_data } }
        end

        if String.method_defined?(:localize)
          puts
          puts "Using twitter_cldr gem (a single time)"
          x.report("NFD:")  { TwitterCldr::Normalization::NFD.normalize  language.test_data }
          x.report("NFKD:") { TwitterCldr::Normalization::NFKD.normalize language.test_data }
          x.report("NFC:")  { TwitterCldr::Normalization::NFC.normalize  language.test_data }
          x.report("NFKC:") { TwitterCldr::Normalization::NFKC.normalize language.test_data }
        end

        if self.class.const_defined?(:ActiveSupport)
          puts
          puts "Using ActiveSupport::Multibyte::Chars (100 times)"
          x.report("NFD:")  { 100.times { ActiveSupport::Multibyte::Chars.new(language.test_data).normalize :d  } }
          x.report("NFKD:") { 100.times { ActiveSupport::Multibyte::Chars.new(language.test_data).normalize :kd } }
          x.report("NFC:")  { 100.times { ActiveSupport::Multibyte::Chars.new(language.test_data).normalize :c  } }
          x.report("NFKC:") { 100.times { ActiveSupport::Multibyte::Chars.new(language.test_data).normalize :kc } }
        end

        if self.class.const_defined?(:Unicode)
          puts
          puts "Using unicode gem (native code, 100 times)"
          x.report("NFD:")  { 100.times { Unicode::normalize_D  language.test_data } }
          x.report("NFKD:") { 100.times { Unicode::normalize_KD language.test_data } }
          x.report("NFC:")  { 100.times { Unicode::normalize_C  language.test_data } }
          x.report("NFKC:") { 100.times { Unicode::normalize_KC language.test_data } }
        end
      end

      puts
    end

  end
end