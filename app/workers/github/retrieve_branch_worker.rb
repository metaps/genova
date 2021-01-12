module Github
  class RetrieveBranchWorker
    include Sidekiq::Worker

    sidekiq_options queue: :github_retrieve_branch, retry: false

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      begin
        session_store = Genova::Slack::SessionStore.new(id)

        bot = Genova::Slack::Bot.new
        bot.post_choose_branch(session_store.params)
      rescue => e
        session_store.clear
        raise e
      end
    end
  end
end
