module Github
  class RetrieveBranchWorker < BaseWorker
    sidekiq_options queue: :github_retrieve_branch, retry: false

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      session_store = Genova::Slack::SessionStore.new(id)

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_branch(session_store.params)
    rescue => e
      slack_notify(e, id)
      raise e
    end
  end
end
