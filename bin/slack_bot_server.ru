require_relative '../config/environment'

ENV['SLACK_CLIENT_ID'] = Settings.slack.client_id.to_s
ENV['SLACK_CLIENT_SECRET'] = Settings.slack.client_secret.to_s

SlackRubyBotServer.configure do |config|
  config.oauth_version = :v2
  config.logger = ::Logger.new(STDOUT)
end

SlackRubyBotServer::Events.configure do |config|
  config.signing_secret = Settings.slack.signing_secret
end

run SlackRubyBotServer::Api::Middleware.instance
