module Slack
  class InteractionWorker < BaseWorker
    sidekiq_options queue: :slack_interaction, retry: false

    def perform(id)
      logger.info('Started Slack::InteractionWorker')

      payload = Genova::Sidekiq::JobStore.find(id)
      Genova::Slack::RequestHandler.call(payload)
    rescue => e
      payload.present? ? slack_notify(e, payload[:container][:thread_ts], payload[:user][:id]) : slack_notify(e)
      raise e
    end
  end
end
