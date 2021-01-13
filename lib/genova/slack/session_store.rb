module Genova
  module Slack
    class SessionStore
      def initialize(timestamp)
        @timestamp = timestamp
      end

      def start
        id = make_id
        write(id, timestamp: @timestamp)
      end

      def add(values)
        write(make_id, params.merge(values))
      end

      def params
        id = make_id
        raise Exceptions::NotFoundError, 'Session does not exist. Please re-run command.' unless Redis.current.exists(id)

        Oj.load(Redis.current.get(id), symbol_keys: true)
      end

      private

      def make_id
        "slack_#{@timestamp}"
      end

      def write(id, values)
        Redis.current.multi do
          Redis.current.set(id, values.to_json)
          Redis.current.expire(id, Settings.slack.interactive.command_timeout)
        end
      end
    end
  end
end
