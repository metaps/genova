module Genova
  module Version
    MAJOR = 4
    MINOR = 4
    TINY = 2

    STRING = [MAJOR, MINOR, TINY].join('.')
    LONG_STRING = "genova v#{[MAJOR, MINOR, TINY].join('.')}".freeze
  end
end
