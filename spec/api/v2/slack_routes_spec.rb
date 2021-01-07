require 'rails_helper'

module V2
  describe SlackRoutes do
    describe 'GET /auth' do
      context 'when you can add team' do
        let(:response_mock) { double(RestClient::Response) }

        it 'should be return success' do
          allow(response_mock).to receive(:body).and_return(Oj.dump({}))
          allow(RestClient).to receive(:post).and_return(response_mock)

          get '/api/v2/slack/auth'
          expect(response).to have_http_status :ok
          expect(response.body).to be_json_eql({})
        end
      end

      context 'when you can\' add team' do
        let(:exception_with_response) { double(RestClient::ExceptionWithResponse) }

        it 'should be return error' do
          allow(exception_with_response).to receive(:body).and_return(Oj.dump(
                                                                        type: 'type',
                                                                        message: 'message'
                                                                      ))
          allow(RestClient).to receive(:post).and_raise(RestClient::ExceptionWithResponse.new(exception_with_response))

          get '/api/v2/slack/auth'
          expect(response).to have_http_status :internal_server_error
          expect(response.body).to be_json_eql(Oj.dump({ type: 'type', message: 'message' }, mode: :strict))
        end
      end
    end

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
            allow(Genova::Slack::RequestHandler).to receive(:handle_request).and_return(
              text: 'text',
              fields: []
            )
            post '/api/v2/slack/post', params: payload_body

            expect(response).to have_http_status :created
            expect(response.body).to be_json_eql('in_channel'.to_json).at_path('response_type')
          end
        end

        context 'when callback_id is invalid' do
          let(:bot_mock) { double(Genova::Slack::Bot) }
          it 'should be return error' do
            allow(bot_mock).to receive(:post_error)

            allow(Genova::Slack::Bot).to receive(:new).and_return(bot_mock)
            allow(Genova::Slack::RequestHandler).to receive(:handle_request).and_raise(Genova::Exceptions::RoutingError.new('No route.'))
            post '/api/v2/slack/post', params: payload_body

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
            post '/api/v2/slack/post', params: payload_body
            expect(response).to have_http_status :forbidden
            expect(response.body).to be_json_eql('Signature do not match.'.to_json).at_path('error')
          end
        end
      end
    end

    describe 'POST /event' do
      context 'when event is sent from Slack' do
        it 'should be return success' do
          post '/api/v2/slack/event', params: { challenge: 'challenge' }
          expect(response).to have_http_status :created
          expect(response.body).to eq('"challenge"')
        end
      end
    end
  end
end
