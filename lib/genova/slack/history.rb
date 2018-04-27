module Genova
  module Slack
    class History
      def initialize(slack_user_id)
        @id = "history_#{slack_user_id}"
      end

      def add(params)
        id = Digest::SHA1.hexdigest("#{params[:account]}#{params[:repository]}#{params[:branch]}#{params[:cluster]}#{params[:service]}")
        value = Oj.dump(
          id: id,
          account: params[:account],
          repository: params[:repository],
          branch: params[:branch],
          cluster: params[:cluster],
          service: params[:service]
        )

        Redis.current.lrem(@id, 1, value) if find(id).present?
        Redis.current.lpush(@id, value)
        Redis.current.rpop(@id) if Redis.current.llen(@id) > Settings.slack.command.max_history
      end

      def list
        Redis.current.lrange(@id, 0, Settings.slack.command.max_history - 1)
      end

      def find(hash_id)
        result = nil

        list.each do |history|
          history = Oj.load(history)

          if history[:id] == hash_id
            result = history
            break
          end
        end

        result
      end

      def last
        result = Redis.current.lindex(@id, 0)
        result = Oj.load(result) if result.present?
        result
      end
    end
  end
end
