module Slack
  class CommandWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_command, retry: false

    def perform(id)
      logger.info('Started Slack::CommandWorker')

      values = Genova::Sidekiq::JobStore.find(id)
      raise Genova::Exceptions::SlackCommandNotFoundError, 'Command not specified.' if values[:text].empty?

      expressions = values[:text].split(' ')
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

      klass = "Genova::Slack::Command::#{statements[:command].capitalize}".safe_constantize
      raise Genova::Exceptions::SlackCommandNotFoundError, "`#{commands[0]}` command does not exist." if klass.nil?

      client = Genova::Slack::Bot.new

      klass.call(client, statements, values[:user])
    end
  end
end
