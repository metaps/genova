module Github
  class RetrieveBranchWorker
    include Sidekiq::Worker

    sidekiq_options queue: :github_retrieve_branch, retry: false

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      params = Genova::Slack::SessionStore.new(id).params

      bot = Genova::Slack::Bot.new
      bot.post_choose_branch(params)
    end
  end
end
