deprecated_envs = %w[
  GENOVA_URL
  GITHUB_PEM
  GITHUB_SECRET_KEY
  SLACK_API_TOKEN
  SLACK_CHANNEL
  SLACK_CLIENT_ID
  SLACK_CLIENT_SECRET
  SLACK_VERIFICATION_TOKEN
]

deprecated_envs.each do |key|
  raise Genova::Exceptions::MigrationError, "The #{key} environment variable has been removed. Please move the variable to the configuration file (https://github.com/metaps/genova/issues/260)." if ENV[key].present?

  raise Genova::Exceptions::MigrationError, "The 'slack.channel' parameter has been discarded. Please use 'slack.channel_id' instead. (https://github.com/slack-ruby/slack-ruby-client/issues/271)." if Settings.slack.channel.present?
end
