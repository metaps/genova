module V2
  class SlackRoutes < Grape::API
    helpers Helper::SlackHelper

    # /api/v2/slack
    resource :slack do
      get :auth do
        slack_host = ENV.fetch('SLACK_HOST', 'slack')
        slack_port = ENV.fetch('SLACK_PORT', 9292)

        logger.warn('Please add "SLACK_HOST" to the environment variable.') if ENV['SLACK_HOST'].nil?
        logger.warn('Please add "SLACK_PORT" to the environment variable.') if ENV['SLACK_PORT'].nil?

        result = RestClient.post("http://#{slack_host}:#{slack_port}/api/teams", code: params[:code], state: params[:state])
        Oj.load(result.body)
      rescue RestClient::ExceptionWithResponse => e
        error!(Oj.load(e.response.body, symbol_keys: true).slice(:type, :message))
      end

      # /api/v2/slack/post
      post :post do
        error! 'Signature do not match.', 403 unless verify_signature?
        result = Genova::Slack::RequestHandler.handle_request(payload_to_json, logger)

        {
          response_type: 'in_channel',
          attachments: [
            {
              color: Settings.slack.message.color.confirm,
              text: result[:text],
              fields: result[:fields]
            }
          ]
        }
      end

      post :event do
        if params['event'].present?
          text = params['event']['blocks'][0]['elements'][0]['elements'].find { |k, v| k['type'] == 'text' }[:text].strip
          expressions = text.split(' ')
          command = expressions[0]
          sub_commands = {}

          if expressions.size > 1
            expressions.slice!(0)
            expressions.each do |sub_command|
              value = sub_command.split('=')
              sub_commands[value[0]] = value[1]
            end
          end

          command_class = "Genova::Slack::Command::#{command.capitalize}"
          client = Genova::Slack::Bot.new
puts '>>>>>>>>>>>>>>>>>>>'
puts text
puts command_class
puts sub_commands

          begin
            Object.const_get(command_class).call(client, command, sub_commands, params['event']['user'], logger)
          rescue NameError
            client.post_simple_message(text: "Command does not exist. [#{command}]")
          end
        end

        params['challenge']
      end
    end
  end
end
