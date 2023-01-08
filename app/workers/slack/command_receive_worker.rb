module Slack
  class CommandReceiveWorker
    include Sidekiq::Worker
    include Genova::Sidekiq::SlackAlert

    sidekiq_options queue: :slack_command_receive, retry: false

    def perform(id)
      logger.info('Started Slack::CommandReceiveWorker')

      values = Genova::Sidekiq::JobStore.find(id)
      raise Genova::Exceptions::NotFoundError, 'Command not specified.' if values[:statement].empty?

      statement = values[:statement].split(' ')
      commands = statement[0].split(':')

      statements = {
        command: commands[0],
        sub_command: commands[1],
        params: {}
      }

      if statement.size > 1
        params = statement.slice(1..)
        params.each do |param|
          element = param.split('=')
          key = element[0].tr('-', '_').to_sym
          statements[:params][key] = element[1]
        end
      end

      klass = "Genova::Slack::Command::#{statements[:command].capitalize}".safe_constantize
      raise Genova::Exceptions::NotFoundError, "`#{commands[0]}` command does not exist." if klass.nil?

      klass.call(statements, values[:user], values[:parent_message_ts])
    rescue => e
      values.present? ? send_error(e, values[:parent_message_ts], values[:user]) : send_error(e)
      raise e
    end
  end
end
