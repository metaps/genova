module Genova
  module Utils
    class String
      class << self
        def pattern_match?(value, search)
          pos = value.index('*')

          if pos.nil?
            search == value
          else
            search.index(value[0, pos]).present?
          end
        end
      end
    end
  end
end
