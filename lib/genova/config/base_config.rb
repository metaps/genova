module Genova
  module Config
    class BaseConfig
      def [](key)
        @params[key]
      end

      def initialize(params)
        @params = params
      end
    end
  end
end
