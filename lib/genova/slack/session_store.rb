module Genova
  module Slack
    class SessionStore
      def initialize(user)
        @user = user
      end

      def start
        id = make_id
        raise Exceptions::SlackSessionConflictError, 'Another command is already running.' if Redis.current.exists(id)

        write(id, user: @user)
      end

      def add(values)
        write(make_id, params.merge(values))
      end

      def params
        id = make_id
        raise Exceptions::NotFoundError, 'Session does not exist. Please re-run command.' unless Redis.current.exists(id)

        Oj.load(Redis.current.get(id), symbol_keys: true)
      end

      def clear
        Redis.current.del(make_id)
      end

      private

      def make_id
        "slack_#{@user}"
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
