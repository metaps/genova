module Genova
  module Sidekiq
    class JobStore
      class << self
        TTL = 1200

        def create(id, params)
          key = generate_key(id)
          # raise Exceptions::DupplicateJobError, 'Duplicate job execution was canceled.' if Genova::RedisPool.get.exists?(key)

          Genova::RedisPool.get.multi do
            Genova::RedisPool.get.set(key, params.to_json)
            Genova::RedisPool.get.expire(key, TTL)
          end

          key
        end

        def find(key)
          values = Genova::RedisPool.get.get(key)
          raise Exceptions::NotFoundError, "Job #{key} not found." if values.nil?

          Oj.load(values, symbol_keys: true)
        end

        private

        def generate_key(id)
          digest = Digest::SHA256.hexdigest(id)
          "job_store_#{digest}"
        end
      end
    end
  end
end
