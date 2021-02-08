module Genova
  module Sidekiq
    class JobStore
      class << self
        TTL = 1800

        def create(params)
          id = "job_store_#{SecureRandom.alphanumeric(4)}"

          Redis.current.multi do
            Redis.current.set(id, params.to_json) if params.present?
            Redis.current.expire(id, TTL)
          end

          id
        end

        def find(id)
          values = Redis.current.get(id)
          raise Exceptions::NotFoundError, "Job #{id} not found." if values.nil?

          Oj.load(values, symbol_keys: true)
        end
      end
    end
  end
end
