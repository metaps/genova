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
        result = $redis.hgetall(id)
        raise QueueNotFoundError, "#{id} is not found." if result.nil?

        result.symbolize_keys
      end

      def update_status(id, status)
        values = find(id)
        return if values.nil?

        values[:status] = status
        $redis.mapped_hmset(id, values)
      end
    end

    class QueueNotFoundError < Error; end
  end
end
