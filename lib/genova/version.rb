module Genova
  module VERSION
    MAJOR = 2
    MINOR = 6
    TINY = 0

    STRING = [MAJOR, MINOR, TINY].compact.join('.')
    LONG_STRING = 'genova v' + [MAJOR, MINOR, TINY].compact.join('.')
  end
end
