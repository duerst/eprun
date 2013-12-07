# encoding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

ROOT_DIR = Pathname.new(File.join(File.dirname(__FILE__)))
$:.push(ROOT_DIR.to_s)

require 'tasks/erb_template'
require 'tasks/tables_generator'
require 'pathname'
require 'rake'

task :generate_tables do
  Eprun::TablesGenerator.new(
    ROOT_DIR.join("data").to_s,
    ROOT_DIR.join("lib/eprun").to_s
  ).generate
end
