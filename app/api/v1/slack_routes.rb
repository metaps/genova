module V1
  class SlackRoutes < Grape::API
    helpers Helper::SlackHelper

    # /api/v1/slack
    resource :slack do
      before do
        error! 'Signature do not match.', 403 unless verify_signature?
        @payload_body = payload_to_json
      end

      # /api/v1/slack/post
      post :post do
        result = Genova::Slack::RequestHandler.handle_request(@payload_body, logger)

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
