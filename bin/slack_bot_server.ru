require_relative '../config/environment'

SlackRubyBotServer.configure do |config|
  config.oauth_version = :v2
  config.oauth_scope = ['app_mentions:read', 'chat:write']

  config.logger = ::Logger.new(STDOUT)
end

run SlackRubyBotServer::Api::Middleware.instance
