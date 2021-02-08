Sidekiq.configure_server do |config|
  config.redis = { url: "redis://#{ENV.fetch('REDIS_HOST')}:#{ENV.fetch('REDIS_PORT')}/#{ENV.fetch('REDIS_DB')}" }
  config.error_handlers << proc { |e, context_hash| Genova::Sidekiq::ErrorHandler.notify(e, context_hash) }
  config.logger.level = Settings.logger.level
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{ENV.fetch('REDIS_HOST')}:#{ENV.fetch('REDIS_PORT')}/#{ENV.fetch('REDIS_DB')}" }
  config.logger.level = Settings.logger.level
end
