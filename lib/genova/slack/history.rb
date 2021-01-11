module Genova
  module Slack
    class History
      def initialize(slack_user_id)
        @id = "history_#{slack_user_id}"
      end

      def add(deploy_job)
        value = Oj.dump(
          id: deploy_job.id,
          type: deploy_job.type.to_s,
          account: deploy_job.account,
          repository: deploy_job.repository,
          branch: deploy_job.branch,
          cluster: deploy_job.cluster,
          base_path: deploy_job.base_path,
          run_task: deploy_job.run_task,
          service: deploy_job.service,
          scheduled_task_rule: deploy_job.scheduled_task_rule,
          scheduled_task_target: deploy_job.scheduled_task_target
        )

        Redis.current.lrem(@id, 1, value) if find(deploy_job.id).present?
        Redis.current.lpush(@id, value)
        Redis.current.rpop(@id) if Redis.current.llen(@id) > Settings.slack.command.max_history
      end

      def list
        Redis.current.lrange(@id, 0, Settings.slack.command.max_history - 1)
      end

      def find(id)
        result = nil

        list.each do |history|
          history = Oj.load(history)

          if history[:id] == id
            result = history
            break
          end
        end

        result
      end

      def find!
        result = find(id)
        raise Genova::Exceptions::NotFoundError, 'History does not exist.' if result.nil?

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
