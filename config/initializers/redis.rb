require 'erb'

config = YAML.load(ERB.new(IO.read(Rails.root.join('config/redis.yml'))).result).deep_symbolize_keys

Redis.current = Redis.new(config[Rails.env.to_sym])
Redis.current.ping
