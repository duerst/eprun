# encoding: utf-8

# Copyright 2010-2013 Ayumu Nojima (野島 歩) and Martin J. Dürst (duerst@it.aoyama.ac.jp)
# available under the same licence as Ruby itself
# (see http://www.ruby-lang.org/en/LICENSE.txt)

class String
  def normalize(form = :nfc)
    Eprun.normalize(self, form)
  end
  
  def normalize!(form = :nfc)
    replace(self.normalize(form))
  end
  
  def normalized?(form = :nfc)
    Eprun.normalized?(self, form)
  end
end

