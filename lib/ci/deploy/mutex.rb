module CI
  module Deploy
    class Mutex
      def initialize(key, ttl = 1800)
        @key = key
        @ttl = ttl
      end

      def lock
        $redis.multi do
          return false unless $redis.setnx(@key, true)
          $redis.expire(@key, @ttl)
        end

        true
      end

      def locked?
        $redis.get(@key) || false
      end

      def unlock
        $redis.del(@key) == 1
      end
    end
  end
end
