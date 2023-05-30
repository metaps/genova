module Genova
  # Genova::RedisPool.getが廃止されたため、独自のコネクションプールを実装。
  # https://www.timedia.co.jp/tech/ruby-rediscurrent/
  class RedisPool
    class Wrapper < ConnectionPool::Wrapper
      def initialize(pool)
        @pool = pool
      end
    end

    class << self
      def with(&block)
        pool.with(&block)
      end

      def get
        Wrapper.new(pool)
      end

      private

      def pool
        @pool ||= ConnectionPool.new do
          config = YAML.unsafe_load(ERB.new(IO.read(Rails.root.join('config/redis.yml'))).result).deep_symbolize_keys
          Redis.new(config[Rails.env.to_sym])
        end
      end
    end
  end
end
