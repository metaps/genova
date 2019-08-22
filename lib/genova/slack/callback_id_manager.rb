module Genova
  module Slack
    class CallbackIdManager
      class << self
        CACHE_TTL = 1800

        def create(action, params = {})
          id = build_id
          datum = {
            action: action
          }

          params.each do |key, value|
            datum[key] = value
          end

          write(id, datum)
          id
        end

        def find(id)
          raise Exceptions::NotFoundError, "Callback ID does not exist. [#{id}]" unless Redis.current.exists(id)

          Redis.current.hgetall(id).symbolize_keys
        end

        private

        def build_id
          "slack_#{Time.new.utc.to_i}"
        end

        def write(id, datum)
          raise Exceptions::ValidationError, "Callback ID already exists. [#{id}]" if Redis.current.exists(id)

          Redis.current.multi do
            Redis.current.mapped_hmset(id, datum)
            Redis.current.expire(id, CACHE_TTL)
          end
        end
      end
    end
  end
end
