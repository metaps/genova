module Github
  class RetrieveBranchWorker < BaseWorker
    sidekiq_options queue: :github_retrieve_branch, retry: false

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      params = Genova::Slack::SessionStore.load(id).params

      transaction = Genova::Utils::DeployTransaction.new(params[:repository], logger)
      transaction.begin

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_branch(params)
    rescue => e
      params.present? ? slack_notify(e, id, params[:user]) : slack_notify(e, id)
      transaction.cancel if transaction.present?
      raise e
    end
  end
end
