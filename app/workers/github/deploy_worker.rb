module Github
  class DeployWorker < BaseWorker
    sidekiq_options queue: :github_deploy, retry: false

    def perform(id)
      logger.info('Started Github::DeployWorker')

      values = Genova::Sidekiq::JobStore.find(id)
      result = find(values[:repository], values[:branch])

      if result.nil?
        logger.info('The pushed branch does not match the conditions of "auto_deploy", so the process is terminated.')
        return
      end

      bot = Genova::Slack::Interactive::Bot.new
      response = bot.detect_auto_deploy(
        account: values[:account],
        repository: values[:repository],
        branch: values[:branch],
        commit_url: values[:commit_url],
        author: values[:author]
      )
      deploy_bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: response[:ts])

      result[:steps].each.with_index(1) do |step, i|
        deploy_bot.start_step(index: i)

        step[:resources].each do |resource|
          service = step[:type] == DeployJob.type.find_value(:service).to_s ? resource : nil
          run_task = step[:type] == DeployJob.type.find_value(:run_task).to_s ? resource : nil

          deploy_job = DeployJob.create!(
            id: DeployJob.generate_id,
            type: DeployJob.type.find_value(step[:type]),
            status: DeployJob.status.find_value(:in_progress),
            mode: DeployJob.mode.find_value(:auto),
            account: values[:account],
            repository: values[:repository],
            branch: values[:branch],
            cluster: step[:cluster],
            service: service,
            scheduled_task_rule: nil,
            scheduled_task_target: nil,
            run_task: run_task
          )

          deploy_bot.start_deploy(deploy_job: deploy_job)
          Genova::Deploy::Runner.call(deploy_job)
          deploy_bot.complete_deploy(deploy_job: deploy_job)
        end
      end

      deploy_bot.finished_steps
    rescue => e
      slack_notify(e)
      raise e
    end

    private

    def find(repository, branch)
      code_manager = Genova::CodeManager::Git.new(repository, branch: branch)
      auto_deploy_config = code_manager.load_deploy_config[:auto_deploy]

      return nil if auto_deploy_config.nil?

      result = auto_deploy_config.find { |k, _v| Genova::Utils::String.pattern_match?(k[:branch], branch) }
      return nil if result.nil?

      result
    end
  end
end
