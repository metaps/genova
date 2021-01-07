module Genova
  module Slack
    class ActionManager
      CACHE_TTL = 1800

      def initialize(route, params = {})
        @datum = {
          route: route
        }

        params.each do |key, value|
          @datum[key] = value
        end
      end

      def create_id
        id = "slack_#{SecureRandom.alphanumeric(8)}"
        write(id, @datum)

        id
      end

      def find(id)
        raise Exceptions::NotFoundError, "Action ID does not exist. [#{id}]" unless Redis.current.exists(id)

        Redis.current.hgetall(id).symbolize_keys
      end

      private

      def write(id, datum)
        raise Exceptions::ValidationError, "Action ID already exists. [#{id}]" if Redis.current.exists(id)

        Redis.current.multi do
          Redis.current.mapped_hmset(id, datum)
          Redis.current.expire(id, CACHE_TTL)
        end
      end
    end
  end
end
