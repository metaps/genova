module Genova
  module Deploy
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

        $redis.lrem(@id, 1, value) if find(id).present?
        $redis.lpush(@id, value)
        $redis.rpop(@id) if $redis.llen(@id) > Settings.slack.command.max_history
      end

      def list
        $redis.lrange(@id, 0, Settings.slack.command.max_history - 1)
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
        result = $redis.lindex(@id, 0)
        result = Oj.load(result) if result.present?
        result
      end
    end
  end
end
