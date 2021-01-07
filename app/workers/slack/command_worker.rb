module Slack
  class CommandWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_command, retry: false

    def perform(id)
      logger.info('Started Slack::CommandWorker')

      queue = Genova::Sidekiq::Queue.find(id)

      expressions = queue.text.split(' ')
      commands = expressions[0].split(':')

      statements = {
        command: commands[0],
        sub_command: commands[1],
        params: {}
      }

      if expressions.size > 1
        params = expressions.slice(1..)
        params.each do |param|
          element = param.split('=')
          key = element[0].tr('-', '_').to_sym
          statements[:params][key] = element[1]
        end
      end

      klass = "Genova::Slack::Command::#{statements[:command].capitalize}"
      raise Genova::Exceptions::InvalidArgumentError, "#{commands[0]} command does not exist." if klass.safe_constantize.nil?

      client = Genova::Slack::Bot.new

      Object.const_get(klass).call(client, statements, queue.user)
    end
  end
end
