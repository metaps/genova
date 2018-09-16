module Genova
  module Utils
    class Mutex
      def initialize(key, cache_ttl = 1800)
        @key = key
        @cache_ttl = cache_ttl
      end

      def lock
        Redis.current.multi do
          return false unless Redis.current.setnx(@key, true)
          Redis.current.expire(@key, @cache_ttl)
        end

        true
      end

      def locked?
        Redis.current.get(@key) || false
      end

      def unlock
        Redis.current.del(@key) == 1
      end
    end
  end
end
