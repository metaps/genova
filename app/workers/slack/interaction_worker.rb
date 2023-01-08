module Slack
  class InteractionWorker
    include Sidekiq::Worker
    include Genova::Sidekiq::SlackAlert

    sidekiq_options queue: :slack_interaction, retry: false

    def perform(id)
      logger.info('Started Slack::InteractionWorker')

      payload = Genova::Sidekiq::JobStore.find(id)
      Genova::Slack::RequestHandler.call(payload)
    rescue => e
      payload.present? ? send_error(e, payload[:container][:thread_ts], payload[:user][:id]) : send_error(e)
      raise e
    end
  end
end
