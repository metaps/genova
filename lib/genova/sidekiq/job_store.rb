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
          params = Oj.load(Redis.current.get(id), symbol_keys: true)
          raise Exceptions::NotFoundError, "#{id} is not found." if params.nil?

          params
        end
      end
    end
  end
end
