# encoding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

module EprunTasks
  class TablesGenerator

    attr_reader :data_dir, :output_dir

    def initialize(data_dir, output_dir)
      @data_dir = data_dir
      @output_dir = output_dir
    end

    UnicodeData = Struct.new(
      :decomposition_table,
      :kompatible_table,
      :combining_classes
    )

    def hash_to_s(hash, unicode_data)
      line_slice(
        hash.collect do |key, value|
          if Eprun.ruby18?
            "#{key.inspect}=>#{value.inspect}, "
          else
            "\"#{to_utf8(key, unicode_data.combining_classes)}\"=>\"#{to_utf8(value, unicode_data.combining_classes)}\", "
          end
        end,
        "\n    "
      )
    end

    # joins items, 16 items per line
    def line_slice(arr, join_char)
      arr.each_slice(16).collect(&:join).join(join_char)
    end

    def to_utf8(obj, combining_classes)
      arr = obj.is_a?(Array) ? obj : [obj]
      if Eprun.ruby18?
        arr.pack("U*").bytes.to_a.map { |s| "\\" + s.to_s(8) }.join
      else
        arr.map do |item|
          if item > 0xFFFF
            "\\u{#{item.to_s(16).upcase}}"
          elsif combining_classes[item] || item == '\\'.ord || item == '"'.ord
            "\\u#{item.to_s(16).upcase.rjust(4, '0')}"
          else
            item.chr(Encoding::UTF_8)
          end
        end.join
      end
    end

    # converts an array of Integers to character ranges
    def arr_to_regexp_chars(arr, unicode_data)
      line_slice(
        arr.sort.inject([]) do |ranges, value|
          if ranges.last and ranges.last[1] + 1 >= value
            ranges.last[1] = value
            ranges
          else
            ranges << [value, value]
          end
        end.collect do |first, last|
          case last - first
            when 0
              to_utf8(first, unicode_data.combining_classes)
            when 1
              to_utf8(first, unicode_data.combining_classes) + to_utf8(last, unicode_data.combining_classes)
            else
              to_utf8(first, unicode_data.combining_classes) + '-' + to_utf8(last, unicode_data.combining_classes)
          end
        end,
        "\" +\n    \""
      )
    end

    def get_composition_exclusions
      IO.readlines(File.join(data_dir, "CompositionExclusions.txt")).
        select { |line| line =~ /^[A-Z0-9]{4,5}/ }.
        collect { |line| line.split(' ').first.hex }
    end

    def get_unicode_data
      decomposition_table = {}
      kompatible_table = {}
      combining_classes = {}

      # read the file 'UnicodeData.txt'
      IO.foreach(File.join(data_dir, "UnicodeData.txt")) do |line|
        codepoint, name, _2, char_class, _4, decomposition, *_rest = line.split(";")

        case decomposition
          when /^[0-9A-F]/
            decomposition_table[codepoint.hex] = decomposition.split(' ').collect(&:hex)
          when /^</
            kompatible_table[codepoint.hex] = decomposition.split(' ').drop(1).collect(&:hex)
        end

        combining_classes[codepoint.hex] = char_class.to_i if char_class != "0"

        if name =~ /(First|Last)>$/ and (char_class != "0" or decomposition != "")
          warn "Unexpected: Character range with data relevant to normalization!"
        end
      end

      UnicodeData.new(decomposition_table, kompatible_table, combining_classes)
    end

    def get_composition_table(unicode_data, composition_exclusions)
      # calculate compositions from decompositions
      unicode_data.decomposition_table.reject do |character, decomposition|
        composition_exclusions.member?(character) or           # predefined composition exclusion
          decomposition.length <= 1 or                         # Singleton Decomposition
          unicode_data.combining_classes[character] or         # character is not a Starter
          unicode_data.combining_classes[decomposition.first]  # decomposition begins with a character that is not a Starter
      end.invert
    end

    def hangul_no_trailing
      @hangul_no_trailing ||= 0xAC00.step(0xD7A3, 28).to_a
    end

    def expand_decomposition_table_values!(decomposition_table)
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
    end

    def relate_decompositions!(decomposition_table, kompatible_table)
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
    end

    def generate
      unicode_data = get_unicode_data
      composition_exclusions = get_composition_exclusions
      composition_table = get_composition_table(unicode_data, composition_exclusions)
      composition_exclusions = unicode_data.decomposition_table.keys - composition_table.values
      accent_array = unicode_data.combining_classes.keys + composition_table.keys.collect(&:last)
      composition_starters = composition_table.keys.collect(&:first)

      expand_decomposition_table_values!(unicode_data.decomposition_table)
      relate_decompositions!(unicode_data.decomposition_table, unicode_data.kompatible_table)

      class_table_str = line_slice(
        unicode_data.combining_classes.collect do |key, value|
          if Eprun.ruby18?
            "#{key.inspect}=>#{value.inspect}, "
          else
            "\"#{to_utf8(key, unicode_data.combining_classes)}\"=>#{value}, "
          end
        end,
        "\n    "
      )

      attrs = {
        :accents => arr_to_regexp_chars(accent_array, unicode_data),
        :composition_starters_and_exclusions => arr_to_regexp_chars(composition_table.values + composition_exclusions, unicode_data),
        :composition_result_characters => arr_to_regexp_chars(composition_starters - composition_table.values, unicode_data),
        :composition_exclusions => arr_to_regexp_chars(composition_exclusions, unicode_data),
        :composition_starters_plus_result_characters => arr_to_regexp_chars(composition_starters + composition_table.values, unicode_data),
        :hangul_separate_trailer => arr_to_regexp_chars(hangul_no_trailing, unicode_data),
        :kompatible_chars => arr_to_regexp_chars(unicode_data.kompatible_table.keys, unicode_data),
        :class_table_str => class_table_str,
        :decomposition_table => hash_to_s(unicode_data.decomposition_table, unicode_data),
        :kompatible_table => hash_to_s(unicode_data.kompatible_table, unicode_data),
        :composition_table => hash_to_s(composition_table, unicode_data)
      }
      
      write_template(attrs)
    end

    def write_template(attrs)
      template = ErbTemplate.new(File.read(template_file), attrs)
      File.open(output_file, "w+") do |f|
        f.write(template.render)
      end
    end

    def output_file
      @output_file ||= File.join(output_dir, "tables.rb")
    end

    def template_file
      @template_file ||= File.join(File.dirname(__FILE__), "tables.rb.erb")
    end

  end
end
