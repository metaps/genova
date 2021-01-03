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
        expressions.slice!(0)
        expressions.each do |param|
          value = param.split('=')
          statements[:params][value[0].to_sym] = value[1]
        end
      end

      command_class = "Genova::Slack::Command::#{statements[:command].capitalize}"
      client = Genova::Slack::Bot.new

      puts '>>>>>>>>>>>>>>>'
      puts statements
      Object.const_get(command_class).call(client, statements, queue.user)
    end
  end
end
