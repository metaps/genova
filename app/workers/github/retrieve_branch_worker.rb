module Github
  class RetrieveBranchWorker < BaseWorker
    sidekiq_options queue: :github_retrieve_branch, retry: false

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      session_store = Genova::Slack::SessionStore.load(id)
      params = session_store.params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_branch(params)
    rescue => e
      params.present? ? slack_notify(e, id, params[:user]) : slack_notify(e, id)
      raise e
    end
  end
end
