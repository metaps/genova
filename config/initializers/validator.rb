if ENV.fetch('SSH_PRIVATE_KEY', nil).nil?
  ENV['SSH_PRIVATE_KEY'] = '/app/.ssh/id_rsa'

  logger = Logger.new(STDOUT)
  logger.warn("Cannot find the environment variable 'SSH_PRIVATE_KEY' in the .env file, please add 'SSH_PRIVATE_KEY=.ssh/id_rsa'.")
end
