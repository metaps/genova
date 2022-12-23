module Genova
  module Deploy
    module Workflow
      class SlackLogger
        def initialize(id)
          @bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
        end

        def step_start(id, step)
          @bot.start_step_deploy(id, step)
        end

        def step_finished(deploy_job)
         @bot.finished_deploy(deploy_job: deploy_job)
        end

        def step_all_finished
          @bot.finished_step_deploy_all
        end
      end
    end
  end
end