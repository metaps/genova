require_relative '../config/environment'
require_relative '../lib/genova/slack/commands'

if ENV.fetch('SLACK_CLIENT_ID').empty?
  STDERR.puts 'SLACK_CLIENT_ID is undefined'
  exit

else
  SlackRubyBot.configure do |config|
    logger = Logger.new('log/slack-ruby-bot.log')
    logger.extend(ActiveSupport::Logger.broadcast(ActiveSupport::Logger.new(STDOUT)))

    config.logger = logger
  end

  SlackRubyBotServer::App.instance.prepare!
  SlackRubyBotServer::Service.start!

  run SlackRubyBotServer::Api::Middleware.instance
end
