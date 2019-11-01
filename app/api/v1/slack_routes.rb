module V1
  class SlackRoutes < Grape::API
    helpers Helper::SlackHelper

    # /api/v1/slack
    resource :slack do
      get :auth do
        begin
          result = RestClient.post('http://slack:9292/api/teams', {code: params[:code], state: params[:state]})
          Oj.load(result.body)

        rescue RestClient::ExceptionWithResponse => e
          error!(Oj.load(e.response.body, symbol_keys: true).slice(:type, :message))
        end
      end

      # /api/v1/slack/post
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
    end
  end
end
