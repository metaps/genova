if ENV.fetch('SSH_PRIVATE_KEY', nil).nil?
  ENV['SSH_PRIVATE_KEY'] = '.ssh/id_rsa'

  logger = Logger.new($stdout)
  logger.warn("Cannot find the environment variable 'SSH_PRIVATE_KEY' in the .env file, please add 'SSH_PRIVATE_KEY=.ssh/id_rsa'.")
end
