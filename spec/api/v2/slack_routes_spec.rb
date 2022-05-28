require 'rails_helper'

module V2
  describe SlackRoutes do
    before do
      remove_key = Genova::Sidekiq::JobStore.send(:generate_key, 'message_ts:message_ts')
      Redis.current.del(remove_key)
    end

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
            token: token,
            message: {
              ts: 'message_ts'
            }
          )
        }
      end

      context 'when valid signature' do
        let(:token) { Settings.slack.vertification_token }

        it 'should be return success' do
          post '/api/v2/slack/post', params: payload_body

          expect(response).to have_http_status :created
        end
      end

      context 'when invalid signature' do
        let(:token) { 'invalid_token' }

        it 'should be return error' do
          post '/api/v2/slack/post', params: payload_body

          expect(response).to have_http_status :forbidden
          expect(response.body).to be_json_eql('Signature do not match.'.to_json).at_path('error')
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
