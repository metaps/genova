require 'erb'

config = YAML.safe_load(ERB.new(IO.read(Rails.root.join('config/redis.yml'))).result, [], [], true).deep_symbolize_keys

Redis.current = Redis.new(config[Rails.env.to_sym])
Redis.current.ping
