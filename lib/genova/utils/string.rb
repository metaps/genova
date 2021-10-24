module Genova
  module Utils
    class String
      class << self
        def pattern_match?(value, search)
          pos = value.index('*')

          matched = if pos.nil?
            search == value
          else
            search.index(value[0, pos]).present?
          end

          matched
        end
      end
    end
  end
end
