module Genova
  module Sidekiq
    class ErrorHandler
      class << self
        def notify(error, context_hash)
          Genova::Slack::Bot.new.post_error(
            error: error,
            deploy_job_id: context_hash[:job]['jid']
          )
        end
      end
    end
  end
end
