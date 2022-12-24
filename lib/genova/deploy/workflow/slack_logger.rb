module Genova
  module Deploy
    module Workflow
      class SlackLogger
        def initialize(id)
          @bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
        end

        def start_step(params)
          @bot.start_step(params)
        end

        def start_deploy(params)
          @bot.start_deploy(params)
        end

        def complete_deploy(params)
          @bot.complete_deploy(deploy_job: params[:deploy_job])
        end

        def complete_steps
          @bot.finished_steps
        end
      end
    end
  end
end
