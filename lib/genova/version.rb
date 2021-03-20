module Genova
  module Version
    MAJOR = 3
    MINOR = 0
    TINY = 7

    STRING = [MAJOR, MINOR, TINY].join('.')
    LONG_STRING = "genova v#{[MAJOR, MINOR, TINY].join('.')}".freeze
  end
end
