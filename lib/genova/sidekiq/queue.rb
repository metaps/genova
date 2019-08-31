module Genova
  module Sidekiq
    class Queue
      extend Enumerize
      enumerize :status, in: %i[complete]

      class << self
        CACHE_TTL = 1800

        def add(values = {})
          id = "job_#{Time.new.utc.to_i}"

          Redis.current.multi do
            Redis.current.mapped_hmset(id, values) if values.present?
            Redis.current.expire(id, CACHE_TTL)
          end

          id
        end

        def find(id)
          values = Redis.current.hgetall(id)
          raise Exceptions::NotFoundError, "#{id} is not found." if values.nil?

          Genova::Sidekiq::Job.new(id, values.symbolize_keys)
        end
      end
    end
  end
end
