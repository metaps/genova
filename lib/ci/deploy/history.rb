module CI
  module Deploy
    class History
      def initialize(slack_user_id)
        @id = build_key(slack_user_id)
      end

      def add(account, repository, branch, service)
        hash_id = Digest::SHA1.hexdigest("#{account}#{repository}#{branch}#{service}")
        value = build_value(hash_id, account, repository, branch, service)

        $redis.lrem(@id, 1, value) if find(hash_id).present?
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

      private

      def build_key(slack_user_id)
        "history_#{slack_user_id}"
      end

      def build_value(hash_id, account, repository, branch, service)
        Oj.dump(
          id: hash_id,
          account: account,
          repository: repository,
          branch: branch,
          service: service
        )
      end
    end
  end
end
