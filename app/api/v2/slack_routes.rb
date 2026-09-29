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

        # A message holding several selects and a button, such as the workflow confirmation,
        # dispatches an action per interaction. Keyed by `message_ts` alone they would share an
        # entry, and the later payload would overwrite the earlier one before its worker reads it,
        # leaving both workers to handle the same action.
        id = "message_ts:#{payload[:message][:ts]}:#{payload.dig(:actions, 0, :action_ts)}"

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
          statement = elements.drop_while { |e| e[:type] != 'user' }.drop(1).filter_map do |e|
            case e[:type]
            when 'text' then e[:text]
            when 'link' then e[:url]
            else nil
            end
          end.join.strip.tr("\u00A0", ' ')

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
