require 'rbtagger'

module Rubotnik
  class Tagger < Brill::Tagger
    def tag(string)
      super.drop(1)
    end
  end
end
