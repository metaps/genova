module Github
  class RetrieveBranchWorker
    include Sidekiq::Worker
    include Genova::Sidekiq::SlackAlert

    sidekiq_options queue: :github_retrieve_branch, retry: false

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      session_store = Genova::Slack::SessionStore.load(id)
      params = session_store.params

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_branch(params)
    rescue => e
      params.present? ? send(e, id, params[:user]) : send(e, id)
      raise e
    end
  end
end
