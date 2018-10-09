# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'
require_relative 'lib/genova/slack/commands'

multiple_loggers = ActiveSupport::Logger.broadcast(ActiveSupport::Logger.new(STDOUT))

logger = Logger.new('log/slack-ruby-bot.log')
logger.extend(multiple_loggers)

SlackRubyBot.configure do |config|
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
logger.info('Start SlackRubyBotServer')

run SlackRubyBotServer::Api::Middleware.instance
run Rails.application
