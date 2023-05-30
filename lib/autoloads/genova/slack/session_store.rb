module Genova
  module Slack
    class SessionStore
      private_class_method :new

      def initialize(id)
        @id = id
      end

      def self.start!(parent_message_ts, user)
        response = Genova::Slack::Client.get('users.info', user:)
        raise Genova::Exceptions::SlackWebAPIError, response[:error] unless response[:ok]

        instance = new(build_id(parent_message_ts))
        instance.merge({ user:, user_name: response[:user][:name] }, false)
        instance
      end

      def self.load(parent_message_ts)
        id = build_id(parent_message_ts)
        raise Genova::Exceptions::NotFoundError, 'Session does not exist. Please re-run command.' unless Genova::RedisPool.get.exists?(id)

        new(id)
      end

      def merge(values, merge = true)
        values = params.merge(values) if merge

        Genova::RedisPool.get.multi do
          Genova::RedisPool.get.set(@id, values.to_json)
          Genova::RedisPool.get.expire(@id, Settings.slack.interactive.command_timeout)
        end
      end

      def params
        Oj.load(Genova::RedisPool.get.get(@id), symbol_keys: true)
      end

      def self.build_id(parent_message_ts)
        "slack_#{parent_message_ts}"
      end
    end
  end
end
