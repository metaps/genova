module Genova
  module Deploy
    module Workflow
      class SlackLogger
        def initialize(id)
          @bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
        end

        def step_start(id, _step)
          @bot.send_message("Start deployment step ##{id}.")
        end

        def step_finished(id, _step)
          @bot.send_message("Finished deployment step ##{id}.")
        end

        def step_all_finished
          @bot.send_message('All deployments are complete.')
        end
      end
    end
  end
end