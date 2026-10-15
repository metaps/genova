require 'rails_helper'

module V2
  describe SlackRoutes do
    let(:signing_secret) { 'signing_secret' }

    def signed_headers(body, content_type: 'application/json', secret: signing_secret, timestamp: Time.now.to_i)
      signature = "v0=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "v0:#{timestamp}:#{body}")}"

      {
        'CONTENT_TYPE' => content_type,
        'HTTP_X_SLACK_REQUEST_TIMESTAMP' => timestamp.to_s,
        'HTTP_X_SLACK_SIGNATURE' => signature
      }
    end

    before do
      allow(Settings.slack).to receive(:signing_secret).and_return(signing_secret)

      remove_key = Genova::Sidekiq::JobStore.send(:generate_key, 'message_ts:message_ts')
      Genova::RedisPool.get.del(remove_key)
    end

    describe 'GET /auth' do
      context 'when you can add team' do
        let(:rest_client_response) { double(RestClient::Response) }

        it 'should return success' do
          allow(rest_client_response).to receive(:body).and_return(Oj.dump({}))
          allow(RestClient).to receive(:post).and_return(rest_client_response)

          get '/api/v2/slack/auth'
          expect(response).to have_http_status :ok
          expect(response.body).to be_json_eql({})
        end
      end

      context 'when you can\' add team' do
        let(:exception_with_response) { double(RestClient::ExceptionWithResponse) }

        it 'should return error' do
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
      let(:body) { URI.encode_www_form(payload: Oj.dump({ message: { ts: 'message_ts' } }, mode: :compat)) }
      let(:content_type) { 'application/x-www-form-urlencoded' }

      context 'when valid signature' do
        it 'should return success' do
          allow(Slack::InteractionWorker).to receive(:perform_async)

          post '/api/v2/slack/post', params: body, headers: signed_headers(body, content_type:)

          expect(response).to have_http_status :created
          expect(Slack::InteractionWorker).to have_received(:perform_async)
        end
      end

      context 'when invalid signature' do
        it 'should return error' do
          allow(Slack::InteractionWorker).to receive(:perform_async)

          post '/api/v2/slack/post', params: body, headers: signed_headers(body, content_type:, secret: 'invalid_secret')

          expect(response).to have_http_status :forbidden
          expect(response.body).to be_json_eql('Signature do not match.'.to_json).at_path('error')
          expect(Slack::InteractionWorker).not_to have_received(:perform_async)
        end
      end

      context 'when body is tampered' do
        it 'should return error' do
          headers = signed_headers(body, content_type:)
          tampered_body = URI.encode_www_form(payload: Oj.dump({ message: { ts: 'tampered' } }, mode: :compat))

          post '/api/v2/slack/post', params: tampered_body, headers: headers

          expect(response).to have_http_status :forbidden
        end
      end

      context 'when timestamp is expired' do
        it 'should return error' do
          post '/api/v2/slack/post', params: body, headers: signed_headers(body, content_type:, timestamp: Time.now.to_i - (60 * 6))

          expect(response).to have_http_status :forbidden
        end
      end

      context 'when signature headers are missing' do
        it 'should return error' do
          post '/api/v2/slack/post', params: body, headers: { 'CONTENT_TYPE' => content_type }

          expect(response).to have_http_status :forbidden
        end
      end

      context 'when legacy verification token is sent without signature' do
        it 'should return error' do
          legacy_body = URI.encode_www_form(payload: Oj.dump({ token: nil, message: { ts: 'message_ts' } }, mode: :compat))

          post '/api/v2/slack/post', params: legacy_body, headers: { 'CONTENT_TYPE' => content_type }

          expect(response).to have_http_status :forbidden
        end
      end

      context 'when signing secret is not configured' do
        it 'should return error' do
          allow(Settings.slack).to receive(:signing_secret).and_return(nil)

          post '/api/v2/slack/post', params: body, headers: signed_headers(body, content_type:, secret: '')

          expect(response).to have_http_status :forbidden
        end
      end
    end

    describe 'POST /event' do
      context 'when event is sent from Slack' do
        it 'should return success' do
          body = Oj.dump({ challenge: 'challenge' }, mode: :compat)
          post '/api/v2/slack/event', params: body, headers: signed_headers(body)

          expect(response).to have_http_status :created
          expect(response.body).to eq('"challenge"')
        end

        it 'ignores unsupported block elements when building statement' do
          allow(Slack::CommandReceiveWorker).to receive(:perform_async)

          body = Oj.dump({
                           event: {
                             user: 'sender',
                             ts: 'parent_ts',
                             event_ts: 'event_ts',
                             blocks: [
                               {
                                 elements: [
                                   {
                                     elements: [
                                       { type: 'user', user_id: 'mention_user' },
                                       { type: 'text', text: "deploy:service\u00A0" },
                                       { type: 'emoji', name: 'rocket' },
                                       { type: 'link', url: 'https://example.com' }
                                     ]
                                   }
                                 ]
                               }
                             ]
                           }
                         }, mode: :compat)

          post '/api/v2/slack/event', params: body, headers: signed_headers(body)

          key = Genova::Sidekiq::JobStore.send(:generate_key, 'event_ts:event_ts')
          value = Genova::Sidekiq::JobStore.find(key)

          expect(value[:statement]).to eq('deploy:service https://example.com')
          expect(value[:mention_user]).to eq('mention_user')
          expect(Slack::CommandReceiveWorker).to have_received(:perform_async).with(key)
        end
      end

      context 'when event is not sent from Slack' do
        it 'should return error' do
          allow(Slack::CommandReceiveWorker).to receive(:perform_async)

          body = Oj.dump({ event: { user: 'sender', ts: 'parent_ts', event_ts: 'event_ts' } }, mode: :compat)
          post '/api/v2/slack/event', params: body, headers: { 'CONTENT_TYPE' => 'application/json' }

          expect(response).to have_http_status :forbidden
          expect(Slack::CommandReceiveWorker).not_to have_received(:perform_async)
        end
      end
    end
  end
end
