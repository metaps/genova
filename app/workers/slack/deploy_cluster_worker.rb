module Slack
  class DeployClusterWorker < BaseWorker
    sidekiq_options queue: :slack_deploy_cluster, retry: false

    def perform(id)
      logger.info('Started Slack::DeployClusterWorker')

      params = Genova::Slack::SessionStore.load(id).params
      response = Genova::Slack::Client.get('users.info', user: params[:user])
      raise Genova::Exceptions::SlackWebAPIError, response[:error] unless response[:ok]

      permission = Genova::Slack::Permission.new(response[:user][:name])
      allow_clusters = permission.allow_clusters(params[:repository], branch: params[:branch], tag: params[:tag], base_path: params[:base_path])
      params[:allow_clusters] = allow_clusters

      bot = Genova::Slack::Interactive::Bot.new(parent_message_ts: id)
      bot.ask_cluster(params)
    rescue => e
      slack_notify(e, id)
      raise e
    end
  end
end
