# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'
require_relative 'lib/genova/slack/commands'

SlackRubyBot.configure do |config|
  logger = Logger.new('log/slack-ruby-bot.log')

  stdout_logger = ActiveSupport::Logger.new(STDOUT)
  multiple_loggers = ActiveSupport::Logger.broadcast(stdout_logger)

  logger.extend(multiple_loggers)
  config.logger = logger
end

SlackRubyBotServer::Service.start!

run SlackRubyBotServer::Api::Middleware.instance
run Rails.application
