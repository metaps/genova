module Genova
  module Version
    MAJOR = 5
    MINOR = 0
    TINY = 0

    STRING = [MAJOR, MINOR, TINY].join('.')
    LONG_STRING = "genova v#{[MAJOR, MINOR, TINY].join('.')}".freeze
  end
end
