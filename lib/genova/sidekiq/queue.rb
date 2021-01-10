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
            Redis.current.set(id, values.to_json) if values.present?
            Redis.current.expire(id, CACHE_TTL)
          end

          id
        end

        def find(id)
          values = Oj.load(Redis.current.get(id), symbol_keys: true)
          raise Exceptions::NotFoundError, "#{id} is not found." if values.nil?

          Genova::Sidekiq::Job.new(id, values)
        end
      end
    end
  end
end
