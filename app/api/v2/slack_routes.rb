module V2
  class SlackRoutes < Grape::API
    helpers Helper::SlackHelper

    # /api/v2/slack
    resource :slack do
      get :auth do
        result = RestClient.post('http://slack:9292/api/teams', code: params[:code], state: params[:state])
        Oj.load(result.body)
      rescue RestClient::ExceptionWithResponse => e
        error!(Oj.load(e.response.body, symbol_keys: true).slice(:type, :message))
      end

      # /api/v2/slack/post
      post :post do
        error! 'Signature do not match.', 403 unless verify_signature?

        payload = payload_to_hash
        id = "message_ts:#{payload[:message][:ts]}"

        key = Genova::Sidekiq::JobStore.create(id, payload)
        Slack::InteractionWorker.perform_async(key)
      end

      post :event do
        if headers['X-Slack-Retry-Num'].present?
          message = "#{headers['X-Slack-Retry-Reason']} (Count: #{headers['X-Slack-Retry-Num']})"
          raise Genova::Exceptions::SlackEventsAPIError, message
        end

        if params[:event].present?
          elements = params.dig(:event, :blocks, 0, :elements, 0, :elements)

          user = elements.find { |k, _v| k[:type] == 'user' }
          element = elements.find { |k, _v| k[:type] == 'text' }

          statement = element.present? ? element[:text].strip.delete("\u00A0") : ''

          key = "event_ts:#{params[:event][:event_ts]}"
          id = Genova::Sidekiq::JobStore.create(key, {
                                                  statement:,
                                                  user: params[:event][:user],
                                                  parent_message_ts: params[:event][:ts],
                                                  mention_user: user[:user_id]
                                                })
          Slack::CommandReceiveWorker.perform_async(id)
        end

        params[:challenge]
      rescue => e
        header 'X-Slack-No-Retry', '1'
        raise e
      end
    end
  end
end
