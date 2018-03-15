module Genova
  module Sidekiq
    class Queue
      ENTITY_EXPIRE = 1800

      extend Enumerize
      enumerize :status, in: %i[standby in_progress complete]

      def add(values = {})
        id = "job_#{Time.new.utc.to_i}"
        values[:status] = Genova::Sidekiq::Queue.status.find_value(:standby)

        $redis.mapped_hmset(id, values)
        $redis.expire(id, ENTITY_EXPIRE)

        id
      end

      def find(id)
        values = $redis.hgetall(id)
        raise QueueNotFoundError, "#{id} is not found." if values.nil?

        Genova::Sidekiq::Job.new(id, values.symbolize_keys)
      end
    end

    class QueueNotFoundError < Error; end
  end
end
