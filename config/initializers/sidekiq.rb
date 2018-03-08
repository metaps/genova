Sidekiq.configure_server do |config|
  config.redis = { url: "redis://#{ENV.fetch('REDIS_HOST')}:#{ENV.fetch('REDIS_PORT')}/#{ENV.fetch('REDIS_DB')}" }
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{ENV.fetch('REDIS_HOST')}:#{ENV.fetch('REDIS_PORT')}/#{ENV.fetch('REDIS_DB')}" }
end
