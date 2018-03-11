require 'rails_helper'

module V1
  describe SlackRoutes do
    describe 'POST /post' do
      let(:payload_body) do
        {
          payload: Oj.dump(
            token: token
          )
        }
      end

      context 'when valid signature' do
        let(:token) { ENV['SLACK_VERIFICATION_TOKEN'] }

        context 'when callback_id is valid' do
          it 'should be return success' do
            allow(Genova::Slack::RequestHandler).to receive(:handle_request)
            post '/api/v1/slack/post', params: payload_body

            expect(response).to have_http_status :created
            expect(response.body).to be_json_eql('in_channel'.to_json).at_path('response_type')
          end
        end

        context 'when callback_id is invalid' do
          it 'should be return error' do
            allow(Genova::Slack::RequestHandler).to receive(:handle_request).and_raise('No route.')
            post '/api/v1/slack/post', params: payload_body

            expect(response).to have_http_status :internal_server_error
            expect(response.body).to be_json_eql('No route.'.to_json).at_path('error')
          end
        end
      end

      context 'when invalid signature' do
        let(:token) { 'invalid_token' }

        context 'when callback_id is blank' do
          let(:callback_id) { '' }

          it 'should be return error' do
            post '/api/v1/slack/post', params: payload_body
            expect(response).to have_http_status :forbidden
            expect(response.body).to be_json_eql('Signature do not match.'.to_json).at_path('error')
          end
        end
      end
    end
  end
end
