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
        payload_body = payload_to_json

        action = payload_body.dig(:actions, 0)
        value = nil

        case action[:type] 
        when 'static_select' then
          value = action[:selected_option][:value]
        when 'button' then
          value = action[:value]
        end

        action_id, timestamp = action[:action_id].split(':')

        if Time.new.to_f - timestamp.to_f > Settings.slack.wait_timeout.to_f
          raise Genova::Exceptions::SlackTimeoutError, 'The command timed out. Please re-run command.'
        end

        id = Genova::Sidekiq::Queue.add(
          action: action_id,
          value: value,
          timestamp: timestamp,
          response_url: payload_body[:response_url]
        )

        Slack::InteractionWorker.perform_async(id)
      end

      post :event do
        if headers['X-Slack-Retry-Num'].present?
          message = "#{headers['X-Slack-Retry-Reason']} (Count: #{headers['X-Slack-Retry-Num']})"
          raise Genova::Exceptions::SlackEventsAPIError, message
        end

        if params[:event].present?
          element = params.dig(:event, :blocks, 0, :elements, 0, :elements).find { |k, _v| k[:type] == 'text' }
          text = element.present? ? element[:text].strip.delete("\u00A0") : ''

          id = Genova::Sidekiq::Queue.add(
            text: text,
            user: params[:event][:user]
          )

          Slack::CommandWorker.perform_async(id)
        end

        params[:challenge]
      end
    end
  end
end
