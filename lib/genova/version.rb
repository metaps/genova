module Genova
  module Version
    MAJOR = 3
    MINOR = 0
    TINY = 0

    STRING = [MAJOR, MINOR, TINY].compact.join('.')
    LONG_STRING = 'genova v' + [MAJOR, MINOR, TINY].compact.join('.')
  end
end
