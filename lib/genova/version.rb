module Genova
  module Version
    MAJOR = 3
    MINOR = 0
    TINY = 8

    STRING = [MAJOR, MINOR, TINY].join('.')
    LONG_STRING = "genova v#{[MAJOR, MINOR, TINY].join('.')}".freeze
  end
end
