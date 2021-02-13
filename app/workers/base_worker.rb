class BaseWorker
  include Sidekiq::Worker

  def slack_notify(error, parent_message_ts = nil, user = nil)
    bot = ::Genova::Slack::Interactive::Bot.new(parent_message_ts: parent_message_ts)
    bot.error(error: error, user: user)
  end
end
