# coding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

require File.join(File.dirname(__FILE__), 'normalize_tables')


module Normalize
  ## Constant for max hash capacity to avoid DoS attack
  MAX_HASH_LENGTH = 18000 # enough for all test cases, otherwise tests get slow
  
  ## Regular Expressions and Hash Constants
  REGEXP_D = Regexp.compile(REGEXP_D_STRING, Regexp::EXTENDED)
  REGEXP_C = Regexp.compile(REGEXP_C_STRING, Regexp::EXTENDED)
  REGEXP_K = Regexp.compile(REGEXP_K_STRING, Regexp::EXTENDED)

  NF_HASH_D = Hash.new do |hash, key|
    hash.delete hash.first[0] if hash.length>MAX_HASH_LENGTH # prevent DoS attack
    hash[key] = Normalize.nfd_one(key)
  end

  NF_HASH_C = Hash.new do |hash, key|
    hash.delete hash.first[0] if hash.length>MAX_HASH_LENGTH # prevent DoS attack
    hash[key] = Normalize.nfc_one(key)
  end

  NF_HASH_K = Hash.new do |hash, key|
    hash.delete hash.first[0] if hash.length>MAX_HASH_LENGTH # prevent DoS attack
    hash[key] = Normalize.nfkd_one(key)
  end
  
  ## Constants For Hangul
  SBASE = 0xAC00
  LBASE = 0x1100
  VBASE = 0x1161
  TBASE = 0x11A7
  LCOUNT = 19
  VCOUNT = 21
  TCOUNT = 28
  NCOUNT = VCOUNT * TCOUNT
  SCOUNT = LCOUNT * NCOUNT

  ## Hangul Algorithm
  def Normalize.hangul_decomp_one(target)
    cps = target.unpack("U*")
    sIndex = cps.first - SBASE
    return target if sIndex < 0 || sIndex >= SCOUNT
    l = LBASE + sIndex / NCOUNT
    v = VBASE + (sIndex % NCOUNT) / TCOUNT
    t = TBASE + sIndex % TCOUNT
    (t == TBASE ? [l, v] : [l, v, t]).pack('U*') + cps[1..-1].pack("U*")
  end
  
  def Normalize.hangul_comp_one(string)
    cps = string.unpack("U*")
    length = cps.length

    condition = length > 1 &&
      0 <= (lead = cps[0] - LBASE) &&
      lead < LCOUNT &&
      0 <= (vowel = cps[1] - VBASE) &&
      vowel < VCOUNT

    if condition
      lead_vowel = SBASE + (lead * VCOUNT + vowel) * TCOUNT
      if length > 2 && 0 <= (trail = cps[2] - TBASE) && trail < TCOUNT
        [lead_vowel + trail].pack("U*") + cps[3..-1].pack("U*")
      else
        [lead_vowel].pack("U*") + cps[2..-1].pack("U*")
      end
    else
      string
    end
  end
  
  ## Canonical Ordering
  def Normalize.canonical_ordering_one(string)
    cps = string.unpack("U*")
    sorting = cps.collect do |c|
      char = [c].pack("U*")
      [char, CLASS_TABLE[char]]
    end
    (sorting.length - 2).downto(0) do |i| # bubble sort
      (0..i).each do |j|
        later_class = sorting[j + 1].last
        if 0 < later_class && later_class < sorting[j].last
          sorting[j], sorting[j + 1] = sorting[j + 1], sorting[j]
        end
      end
    end
    sorting.collect(&:first).join
  end
  
  ## Normalization Forms for Patterns (not whole Strings)
  def Normalize.nfd_one(string)
    cps = string.unpack("U*")
    cps = cps.inject([]) do |ret, cp|
      if decomposition = DECOMPOSITION_TABLE[[cp].pack("U*")]
        ret += decomposition.unpack("U*")
      else
        ret << cp
      end
    end

    canonical_ordering_one(hangul_decomp_one(cps.pack("U*")))
  end

  def Normalize.nfkd_one(string)
    cps = string.unpack("U*")
    final_cps = []
    position = 0
    while position < cps.length
      if decomposition = KOMPATIBLE_TABLE[[cps[position]].pack("U*")]
        final_cps += nfkd_one(decomposition).unpack("U*")
      else
        final_cps << cps[position]
      end
      position += 1
    end
    final_cps.pack("U*")
  end
  
  def Normalize.nfc_one (string)
    nfd_string = nfd_one(string)
    nfd_string_cp = nfd_string.unpack("U*")
    start = [nfd_string_cp[0]].pack("U*")
    last_class = CLASS_TABLE[start] - 1
    accents = ''
    nfd_string_cp[1..-1].each do |accent_cp|
      accent = [accent_cp].pack("U*")
      accent_class = CLASS_TABLE[accent]
      if last_class < accent_class && composite = COMPOSITION_TABLE[start + accent]
        start = composite
      else
        accents += accent
        last_class = accent_class
      end
    end
    hangul_comp_one(start + accents)
  end

  def Normalize.normalize(string, form = :nfc)
    case form
      when :nfc then
        string.gsub(REGEXP_C) { |s| NF_HASH_C[s] }
      when :nfd then
        string.gsub(REGEXP_D) { |s| NF_HASH_D[s] }
      when :nfkc then
        string.gsub(REGEXP_K) { |s| NF_HASH_K[s] }.gsub(REGEXP_C) { |s| NF_HASH_C[s] }
      when :nfkd then
        string.gsub(REGEXP_K) { |s| NF_HASH_K[s] }.gsub(REGEXP_D) { |s| NF_HASH_D[s] }
      else
        raise ArgumentError, "Invalid normalization form #{form}."
    end
  end
  
  def Normalize.normalized?(string, form = :nfc)
    case form
    when :nfc then
      string.scan REGEXP_C do |match|
        return false if NF_HASH_C[match] != match
      end
      true
    when :nfd then
      string.scan REGEXP_D do |match|
        return false if NF_HASH_D[match] != match
      end
      true
    when :nfkc then
      normalized?(string, :nfc) && string !~ REGEXP_K
    when :nfkd then
      normalized?(string, :nfd) && string !~ REGEXP_K
    else
      raise ArgumentError, "Invalid normalization form #{form}."
    end
  end
  
end # module
