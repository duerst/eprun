# encoding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

require 'spec_helper'

NormTest = Struct.new(:source, :NFC, :NFD, :NFKC, :NFKD, :line)

def read_tests(data_dir)
  IO.readlines(File.join(data_dir, 'NormalizationTest.txt')).
    collect.with_index { |linedata, linenumber| [linedata, linenumber] }.
    reject { |line| line[0] =~ /^[\#@]/ }.
    collect do |line|
      NormTest.new(
        *(line[0].to_s.split(';').take(5).collect do |code_string|
          code_string.split(/\s/).collect { |cp| cp.to_i(16) }.pack('U*')
        end + [line[1] + 1])
      )
  end
end

def to_codepoints(string)
  string.unpack("U*").collect { |cp| cp.to_s(16).upcase.rjust(4, '0') }.join(" ")
end

def generate_normalize_spec(target, normalization, source, prechecked)
  it "tests normalization to #{target} from #{source} with #{normalization}" do
    tests.each do |test|
      if not prechecked or test[source] == test[prechecked]
        expected = test[target]
        actual = test[source].normalize(normalization)
        message = if debug?
          "#{to_codepoints(expected)} expected but was #{to_codepoints(actual)} on line #{test.line} (#{normalization})"
        end
        actual.should(eq(expected), message)
      end
    end
  end
end

def generate_normalization_check_true_spec(source, normalization)
  it "checks that #{source} is normalized with #{normalization}" do
    tests.each do |test|
      actual = test[source].normalized?(normalization)
      message = if debug?
        "#{to_codepoints(test[source])} should check as #{normalization} but does not on line #{test[:line]}"
      end
      actual.should(be_true, message)
    end
  end
end

def generate_normalization_check_false_spec(source, compare, normalization)
  it "checks that #{source} is not normalized with #{normalization}" do
    tests.each do |test|
      if test[source] != test[compare]
        actual = test[source].normalized?(normalization)
        message = if debug?
          "#{to_codepoints(test[source])} should not check as #{normalization} but does on line #{test[:line]}"
        end
        actual.should(be_false, message)
      end
    end
  end
end

def utf8(str)
  str.split("\\u")[1..-1].map { |s| s.to_i(16) }.pack("U*")
end

describe Eprun::Normalizer do
  # If true, generation of explicit error messages is switched on.
  # False is about two times faster than true.
  let(:data_dir) { File.join(File.dirname(File.dirname(__FILE__)), "data") }
  let(:debug?) { ENV["DEBUG"] == "true" }
  let(:tests) { read_tests(data_dir) }

  describe "#normalize" do
    #      source; NFC; NFD; NFKC; NFKD
    #    NFC
    #      :NFC ==  toNFC(:source) ==  toNFC(:NFC) ==  toNFC(:NFD)
    generate_normalize_spec :NFC, :nfc, :source, nil
    generate_normalize_spec :NFC, :nfc, :NFC, :source
    generate_normalize_spec :NFC, :nfc, :NFD, :source
    #      :NFKC ==  toNFC(:NFKC) ==  toNFC(:NFKD)
    generate_normalize_spec :NFKC, :nfc, :NFKC, nil
    generate_normalize_spec :NFKC, :nfc, :NFKD, :NFKC
    #
    #    NFD
    #      :NFD ==  toNFD(:source) ==  toNFD(:NFC) ==  toNFD(:NFD)
    generate_normalize_spec :NFD, :nfd, :source, nil
    generate_normalize_spec :NFD, :nfd, :NFC, :source
    generate_normalize_spec :NFD, :nfd, :NFD, :source
    #      :NFKD ==  toNFD(:NFKC) ==  toNFD(:NFKD)
    generate_normalize_spec :NFKD, :nfd, :NFKC, nil
    generate_normalize_spec :NFKD, :nfd, :NFKD, :NFKC
    #
    #    NFKC
    #      :NFKC == toNFKC(:source) == toNFKC(:NFC) == toNFKC(:NFD) == toNFKC(:NFKC) == toNFKC(:NFKD)
    generate_normalize_spec :NFKC, :nfkc, :source, nil
    generate_normalize_spec :NFKC, :nfkc, :NFC, :source
    generate_normalize_spec :NFKC, :nfkc, :NFD, :source
    generate_normalize_spec :NFKC, :nfkc, :NFKC, :NFC
    generate_normalize_spec :NFKC, :nfkc, :NFKD, :NFD
    #
    #    NFKD
    #      :NFKD == toNFKD(:source) == toNFKD(:NFC) == toNFKD(:NFD) == toNFKD(:NFKC) == toNFKD(:NFKD)
    generate_normalize_spec :NFKD, :nfkd, :source, nil
    generate_normalize_spec :NFKD, :nfkd, :NFC, :source
    generate_normalize_spec :NFKD, :nfkd, :NFD, :source
    generate_normalize_spec :NFKD, :nfkd, :NFKC, :NFC
    generate_normalize_spec :NFKD, :nfkd, :NFKD, :NFD

    it "should properly normalize singletons with accents" do
      utf8('\u212A\u0327').normalize(:nfc).should == utf8('\u0136')
    end

    it "should properly compose partial jamo characters" do
      utf8('\uAC00\u11A8').normalize(:nfc).should == utf8('\uAC01')
    end
    
    it "should properly decompose parial jamo characters" do
      utf8('\uAC00\u11A8').normalize(:nfd).should == utf8('\u1100\u1161\u11A8')
    end

    it "should propery normalize hangul characters with accents" do
      utf8('\uAC00\u0300\u0323').normalize(:nfc).should == utf8('\uAC00\u0323\u0300')
      utf8('\u1100\u1161\u0300\u0323').normalize(:nfc).should == utf8('\uAC00\u0323\u0300')
      utf8('\uAC00\u0300\u0323').normalize(:nfd).should == utf8('\u1100\u1161\u0323\u0300')
      utf8('\u1100\u1161\u0300\u0323').normalize(:nfd).should == utf8('\u1100\u1161\u0323\u0300')
    end
  end

  describe "#normalized?" do
    generate_normalization_check_true_spec :NFC, :nfc
    generate_normalization_check_true_spec :NFD, :nfd
    generate_normalization_check_true_spec :NFKC, :nfc
    generate_normalization_check_true_spec :NFKC, :nfkc
    generate_normalization_check_true_spec :NFKD, :nfd
    generate_normalization_check_true_spec :NFKD, :nfkd

    generate_normalization_check_false_spec :source, :NFD, :nfd
    generate_normalization_check_false_spec :NFC, :NFD, :nfd
    generate_normalization_check_false_spec :NFKC, :NFKD, :nfd
    generate_normalization_check_false_spec :source, :NFC, :nfc
    generate_normalization_check_false_spec :NFD, :NFC, :nfc
    generate_normalization_check_false_spec :NFKD, :NFKC, :nfc
    generate_normalization_check_false_spec :source, :NFKD, :nfkd
    generate_normalization_check_false_spec :NFC, :NFKD, :nfkd
    generate_normalization_check_false_spec :NFD, :NFKD, :nfkd
    generate_normalization_check_false_spec :NFKC, :NFKD, :nfkd
    generate_normalization_check_false_spec :source, :NFKC, :nfkc
    generate_normalization_check_false_spec :NFC, :NFKC, :nfkc
    generate_normalization_check_false_spec :NFD, :NFKC, :nfkc
    generate_normalization_check_false_spec :NFKD, :NFKC, :nfkc
  end
end
