module Genova
  module Sidekiq
    class ErrorHandler
      class << self
        def notify(error, context_hash)
          ::Sidekiq::Logging.logger.error(error)

          context_hash.symbolize_keys!
          job = context_hash[:job]

          bot = ::Genova::Slack::Bot.new(parent_message_ts: job[:args][0])
          bot.post_error(
            error: error,
            deploy_job_id: job[:jid]
          )
        end
      end
    end
  end
end
