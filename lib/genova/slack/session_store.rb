module Genova
  module Slack
    class SessionStore
      def initialize(user)
        @user = user
      end

      def create
        write(user: @user)
      end

      def add(values)
        write(params.merge(values))
      end

      def params
        id = build_id
        raise Exceptions::NotFoundError, "Session does not exist. Please re-run command." unless Redis.current.exists(id)

        Oj.load(Redis.current.get(id), symbol_keys: true)
      end

      def clear
        Redis.current.del(build_id)
      end

      private

      def build_id
        "slack_#{@user}"
      end

      def write(values)
        id = build_id

        Redis.current.multi do
          Redis.current.set(id, values.to_json)
          Redis.current.expire(id, Settings.slack.interactive.command_timeout)
        end
      end
    end
  end
end
