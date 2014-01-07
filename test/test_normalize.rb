# encoding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

$KCODE = 'utf-8' unless RUBY_VERSION >= '1.9.0'

require 'eprun'

NormTest = Struct.new(:source, :NFC, :NFD, :NFKC, :NFKD, :line)

class TestNormalize < Test::Unit::TestCase
  @@debug = false # if true, generation of explicit error messages is switched on
                  # false is about two times faster than true

  def read_tests
    IO.readlines(File.join(File.dirname(__FILE__), '../data/NormalizationTest.txt')).
      each_with_index.collect { |linedata, linenumber| [linedata, linenumber] }.
      reject { |line| line[0] =~ /^[\#@]/ }.
      collect do |line|
        NormTest.new(
          *(line[0].to_s.split(';').take(5).collect do |code_string|
            code_string.split(/\s/).collect { |cp| cp.to_i(16) }.pack('U*')
          end + [line[1] + 1])
        )
    end
  end

  def to_codepoints(string) # this could be defined as a refinement on String
    string.unpack("U*").collect { |cp| cp.to_s(16).upcase.rjust(4, '0') }.join(" ")
  end

  def setup
    @@tests ||= read_tests
  end

  def self.generate_test_normalize(target, normalization, source, prechecked)
    define_method "test_normalize_to_#{target}_from_#{source}_with_#{normalization}" do
      @@tests.each do |test|
        if not prechecked or test[source] == test[prechecked]
          expected = test[target]
          actual = Eprun.normalize(test[source], normalization)

          if @@debug
            assert_equal(
              expected, actual,
              "#{to_codepoints(expected)} expected but was #{to_codepoints(actual)} on line #{test[:line]} (#{normalization})"
            )
          else
            assert_equal(expected, actual)
          end
        end
      end
    end
  end

#      source; NFC; NFD; NFKC; NFKD
#    NFC
#      :NFC ==  toNFC(:source) ==  toNFC(:NFC) ==  toNFC(:NFD)
  generate_test_normalize :NFC, :nfc, :source, nil
  generate_test_normalize :NFC, :nfc, :NFC, :source
  generate_test_normalize :NFC, :nfc, :NFD, :source
#      :NFKC ==  toNFC(:NFKC) ==  toNFC(:NFKD)
  generate_test_normalize :NFKC, :nfc, :NFKC, nil
  generate_test_normalize :NFKC, :nfc, :NFKD, :NFKC
#
#    NFD
#      :NFD ==  toNFD(:source) ==  toNFD(:NFC) ==  toNFD(:NFD)
  generate_test_normalize :NFD, :nfd, :source, nil
  generate_test_normalize :NFD, :nfd, :NFC, :source
  generate_test_normalize :NFD, :nfd, :NFD, :source
#      :NFKD ==  toNFD(:NFKC) ==  toNFD(:NFKD)
  generate_test_normalize :NFKD, :nfd, :NFKC, nil
  generate_test_normalize :NFKD, :nfd, :NFKD, :NFKC
#
#    NFKC
#      :NFKC == toNFKC(:source) == toNFKC(:NFC) == toNFKC(:NFD) == toNFKC(:NFKC) == toNFKC(:NFKD)
  generate_test_normalize :NFKC, :nfkc, :source, nil
  generate_test_normalize :NFKC, :nfkc, :NFC, :source
  generate_test_normalize :NFKC, :nfkc, :NFD, :source
  generate_test_normalize :NFKC, :nfkc, :NFKC, :NFC
  generate_test_normalize :NFKC, :nfkc, :NFKD, :NFD
#
#    NFKD
#      :NFKD == toNFKD(:source) == toNFKD(:NFC) == toNFKD(:NFD) == toNFKD(:NFKC) == toNFKD(:NFKD)
  generate_test_normalize :NFKD, :nfkd, :source, nil
  generate_test_normalize :NFKD, :nfkd, :NFC, :source
  generate_test_normalize :NFKD, :nfkd, :NFD, :source
  generate_test_normalize :NFKD, :nfkd, :NFKC, :NFC
  generate_test_normalize :NFKD, :nfkd, :NFKD, :NFD

  def self.generate_test_check_true(source, normalization)
    define_method "test_check_true_#{source}_as_#{normalization}" do
      @@tests.each do |test|
        actual = Eprun.normalized?(test[source], normalization)

        if @@debug
          assert_equal(
            true, actual,
            "#{to_codepoints(test[source])} should check as #{normalization} but does not on line #{test[:line]}"
          )
        else
          assert_equal(true, actual)
        end
      end
    end
  end

  def one_false_check_test(test, compare_column, check_column, test_form, line)
    if test[check_column - 1] != test[compare_column - 1]
      actual = test[check_column - 1].normalized?(test_form)
      assert_equal(false, actual, "failed on line #{line + 1} (#{test_form})")
    end
  end

  def self.generate_test_check_false(source, compare, normalization)
    define_method "test_check_false_#{source}_as_#{normalization}" do
      @@tests.each do |test|
        if test[source] != test[compare]
          actual = Eprun.normalized?(test[source], normalization)

          if @@debug
            assert_equal(
              false, actual,
              "#{to_codepoints(test[source])} should not check as #{normalization} but does on line #{test[:line]}"
            )
          else
            assert_equal(false, actual)
          end
        end
      end
    end
  end

  generate_test_check_true :NFC, :nfc
  generate_test_check_true :NFD, :nfd
  generate_test_check_true :NFKC, :nfc
  generate_test_check_true :NFKC, :nfkc
  generate_test_check_true :NFKD, :nfd
  generate_test_check_true :NFKD, :nfkd

  generate_test_check_false :source, :NFD, :nfd
  generate_test_check_false :NFC, :NFD, :nfd
  generate_test_check_false :NFKC, :NFKD, :nfd
  generate_test_check_false :source, :NFC, :nfc
  generate_test_check_false :NFD, :NFC, :nfc
  generate_test_check_false :NFKD, :NFKC, :nfc
  generate_test_check_false :source, :NFKD, :nfkd
  generate_test_check_false :NFC, :NFKD, :nfkd
  generate_test_check_false :NFD, :NFKD, :nfkd
  generate_test_check_false :NFKC, :NFKD, :nfkd
  generate_test_check_false :source, :NFKC, :nfkc
  generate_test_check_false :NFC, :NFKC, :nfkc
  generate_test_check_false :NFD, :NFKC, :nfkc
  generate_test_check_false :NFKD, :NFKC, :nfkc

  def utf8(str)
    str.split("\\u")[1..-1].map { |s| s.to_i(16) }.pack("U*")
  end

  def test_singleton_with_accents
    assert_equal utf8('\u0136'), Eprun.normalize(utf8('\u212A\u0327'), :nfc)
  end

  def test_partial_jamo_compose
    assert_equal utf8('\uAC01'), Eprun.normalize(utf8('\uAC00\u11A8'), :nfc)
  end

  def test_partial_jamo_decompose
    assert_equal utf8('\u1100\u1161\u11A8'), Eprun.normalize(utf8('\uAC00\u11A8'), :nfd)
  end

  def test_hangul_plus_accents
    assert_equal utf8('\uAC00\u0323\u0300'), Eprun.normalize(utf8('\uAC00\u0300\u0323'), :nfc)
    assert_equal utf8('\uAC00\u0323\u0300'), Eprun.normalize(utf8('\u1100\u1161\u0300\u0323'), :nfc)
    assert_equal utf8('\u1100\u1161\u0323\u0300'), Eprun.normalize(utf8('\uAC00\u0300\u0323'), :nfd)
    assert_equal utf8('\u1100\u1161\u0323\u0300'), Eprun.normalize(utf8('\u1100\u1161\u0300\u0323'), :nfd)
  end
end

