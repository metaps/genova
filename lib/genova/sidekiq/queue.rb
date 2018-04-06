module Genova
  module Sidekiq
    class Queue
      extend Enumerize
      enumerize :status, in: %i[standby in_progress complete]

      class << self
        ENTITY_EXPIRE = 1800

        def add(values = {})
          id = "job_#{Time.new.utc.to_i}"
          values[:status] = Genova::Sidekiq::Queue.status.find_value(:standby)

          Redis.current.mapped_hmset(id, values)
          Redis.current.expire(id, ENTITY_EXPIRE)

          id
        end

        def find(id)
          values = Redis.current.hgetall(id)
          raise QueueError, "#{id} is not found." if values.nil?

          Genova::Sidekiq::Job.new(id, values.symbolize_keys)
        end
      end
    end

    class QueueError < Error; end
  end
end
