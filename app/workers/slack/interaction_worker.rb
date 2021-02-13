module Slack
  class InteractionWorker < BaseWorker
    sidekiq_options queue: :slack_interaction, retry: false

    def perform(id)
      logger.info('Started Slack::InteractionWorker')

      payload = Genova::Sidekiq::JobStore.find(id)
      Genova::Slack::RequestHandler.call(payload)
    rescue => e
      if payload.present?
        slack_notify(e, payload[:container][:thread_ts], payload[:user][:id])
      else
        slack_notify(e)
      end

      raise e
    end
  end
end
