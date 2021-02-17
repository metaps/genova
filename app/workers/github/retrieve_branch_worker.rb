module Github
  class RetrieveBranchWorker < BaseWorker
    sidekiq_options queue: :github_retrieve_branch, retry: false

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      session_store = Genova::Slack::SessionStore.load(id)
      params = session_store.params
      transaction = Genova::Utils::DeployTransaction.new(params[:repository])

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.send_message('Please wait as other deployments are in progress.') if transaction.exist?

      transaction.begin
      bot.ask_branch(params)
    rescue => e
      params.present? ? slack_notify(e, id, params[:user]) : slack_notify(e, id)
      transaction.cancel if transaction.present?
      raise e
    end
  end
end
