module Github
  class RetrieveBranchWorker < BaseWorker
    sidekiq_options queue: :github_retrieve_branch, retry: false

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      params = Genova::Slack::SessionStore.load(id).params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_branch(params)
    rescue => e
      if params.present?
        slack_notify(e, id, params[:user])
      else
        slack_notify(e, id)
      end

      raise e
    end
  end
end
