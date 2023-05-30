module Genova
  module Slack
    module Interactive
      class History
        def initialize(user)
          @id = "history_#{user}"
        end

        def add(deploy_job)
          value = Oj.dump(
            id: deploy_job.id,
            type: deploy_job.type.to_s,
            alias: deploy_job.alias,
            account: deploy_job.account,
            repository: deploy_job.repository,
            branch: deploy_job.branch,
            tag: deploy_job.tag,
            cluster: deploy_job.cluster,
            run_task: deploy_job.run_task,
            override_container: deploy_job.override_container,
            override_command: deploy_job.override_command,
            service: deploy_job.service,
            scheduled_task_rule: deploy_job.scheduled_task_rule,
            scheduled_task_target: deploy_job.scheduled_task_target
          )

          Genova::RedisPool.get.lrem(@id, 1, value) if find(deploy_job.id).present?
          Genova::RedisPool.get.lpush(@id, value)
          Genova::RedisPool.get.rpop(@id) if Genova::RedisPool.get.llen(@id) > Settings.slack.command.max_history
        end

        def list
          Genova::RedisPool.get.lrange(@id, 0, Settings.slack.command.max_history - 1)
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

        def find!(id)
          result = find(id)
          raise Genova::Exceptions::NotFoundError, 'History does not exist.' if result.nil?

          result
        end

        def last
          result = Genova::RedisPool.get.lindex(@id, 0)
          result = Oj.load(result) if result.present?
          result
        end
      end
    end
  end
end
