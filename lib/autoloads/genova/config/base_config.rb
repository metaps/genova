module Genova
  module Config
    class BaseConfig
      def [](key)
        @params[key]
      end

      def initialize(params)
        @params = params
        validate!
      end

      def validate!; end
    end
  end
end
