require_relative '../config/environment'
require_relative '../lib/genova/slack/commands'

SlackRubyBot.configure do |config|
  logger = Logger.new('log/slack-ruby-bot.log')
  logger.extend(ActiveSupport::Logger.broadcast(ActiveSupport::Logger.new(STDOUT)))

  config.logger = logger
end

SlackRubyBotServer.configure do |config|
  config.ping = {
    enabled: true,
    ping_interval: 30,
    retry_count: 3
  }
end

SlackRubyBotServer::App.instance.prepare!
SlackRubyBotServer::Service.start!

run SlackRubyBotServer::Api::Middleware.instance
