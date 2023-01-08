module Genova
  module Sidekiq
    class JobStore
      class << self
        TTL = 1200

        def create(id, params)
          key = generate_key(id)
          # raise Exceptions::DupplicateJobError, 'Duplicate job execution was canceled.' if Redis.current.exists?(key)

          Redis.current.multi do
            Redis.current.set(key, params.to_json)
            Redis.current.expire(key, TTL)
          end

          key
        end

        def find(key)
          values = Redis.current.get(key)
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
