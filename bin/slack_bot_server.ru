require_relative '../config/environment'

SlackRubyBotServer.configure do |config|
  config.oauth_version = :v2
  config.logger = ::Logger.new(STDOUT)
  config.signing_secret = Settings.slack.signing_secret
end

run SlackRubyBotServer::Api::Middleware.instance
