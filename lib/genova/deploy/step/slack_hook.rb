module Genova
  module Deploy
    module Step
      class SlackHook
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
          @bot.complete_deploy(params)
        end

        def complete_steps
          @bot.complete_steps
        end
      end
    end
  end
end
