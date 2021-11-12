module Genova
  module Version
    MAJOR = 3
    MINOR = 2
    TINY = 1

    STRING = [MAJOR, MINOR, TINY].join('.')
    LONG_STRING = "genova v#{[MAJOR, MINOR, TINY].join('.')}".freeze
  end
end
