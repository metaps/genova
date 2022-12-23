module Genova
  module Deploy
    module Workflow
      class SlackLogger
        def initialize(id)
          @bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
        end

        def start_step(params)
          @bot.start_auto_deploy_step(params)
        end

        def start_deploy(params)
          @bot.start_auto_deploy_run(params)
        end

        def finished_deploy(params)
          @bot.finished_deploy(deploy_job: params[:deploy_job])
        end

        def finished_all_deploy
          @bot.finished_auto_deploy_all
        end
      end
    end
  end
end
