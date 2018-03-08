require 'erb'

REDIS_CONFIG = YAML.load(ERB.new(IO.read(Rails.root.join('config/redis.yml'))).result).symbolize_keys
config = REDIS_CONFIG[:default].symbolize_keys
config = config.merge(REDIS_CONFIG[Rails.env.to_sym].symbolize_keys) if REDIS_CONFIG[Rails.env.to_sym]

$redis = Redis.new(config)
$redis.ping
