module Genova
  module Version
    MAJOR = 4
    MINOR = 3
    TINY = 3

    STRING = [MAJOR, MINOR, TINY].join('.')
    LONG_STRING = "genova v#{[MAJOR, MINOR, TINY].join('.')}".freeze
  end
end
