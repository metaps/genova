require 'rails_helper'

module V2
  describe GithubRoutes do
    describe 'POST /api/v2/github/push' do
      let(:webhook_pushed_commit) do
        Oj.dump(
          {
            repository: {
              name: 'repository',
              owner: {
                name: 'owner'
              },
              pushed_at: 'pushed_at'
            },
            ref: 'refs/heads/xxx',
            head_commit: {
              url: 'url',
              author: {
                username: 'username'
              }
            }
          },
          mode: :compat
        )
      end

      let(:webhook_pushed_tag) do
        Oj.dump(
          {
            repository: {
              name: 'repository',
              owner: {
                name: 'owner'
              },
              pushed_at: 'pushed_at'
            },
            ref: 'refs/tags/xxx',
            head_commit: {
              url: 'url',
              author: {
                username: 'username'
              }
            }
          },
          mode: :compat
        )
      end

      before do
        allow(Settings.github).to receive(:secret_key).and_return('')

        remove_key = Genova::Sidekiq::JobStore.send(:generate_key, 'pushed_at:pushed_at')
        Genova::RedisPool.get.del(remove_key)
      end

      context 'when valid signature' do
        digest = OpenSSL::Digest.new('sha1')

        context 'when branch is pushed' do
          let(:signature) { "sha1=#{OpenSSL::HMAC.hexdigest(digest, Settings.github.secret_key, webhook_pushed_commit)}" }
          let(:headers) { { 'HTTP_X_HUB_SIGNATURE' => signature, 'CONTENT_TYPE' => 'application/json' } }

          it 'should return success' do
            allow(Github::DeployWorker).to receive(:perform_async)
            post('/api/v2/github/push', params: webhook_pushed_commit, headers:)
            expect(response).to have_http_status :created
          end
        end

        context 'when tag is pushed' do
          let(:signature) { "sha1=#{OpenSSL::HMAC.hexdigest(digest, Settings.github.secret_key, webhook_pushed_tag)}" }
          let(:headers) { { 'HTTP_X_HUB_SIGNATURE' => signature, 'CONTENT_TYPE' => 'application/json' } }

          it 'should return error' do
            allow(Github::DeployWorker).to receive(:perform_async)
            post('/api/v2/github/push', params: webhook_pushed_tag, headers:)
            expect(response).to have_http_status :forbidden
          end
        end
      end

      context 'when invalid signature' do
        let(:signature) { 'sha1=invalid_signature' }
        let(:headers) { { 'HTTP_X_HUB_SIGNATURE' => signature, 'CONTENT_TYPE' => 'application/json' } }

        it 'should return error' do
          post('/api/v2/github/push', params: webhook_pushed_commit, headers:)
          expect(response).to have_http_status :forbidden
        end

        it 'should not parse payload' do
          allow(Oj).to receive(:load).and_call_original

          post('/api/v2/github/push', params: webhook_pushed_commit, headers:)

          expect(Oj).not_to have_received(:load)
        end
      end

      context 'when signature header is missing' do
        it 'should return error' do
          post('/api/v2/github/push', params: webhook_pushed_commit, headers: { 'CONTENT_TYPE' => 'application/json' })
          expect(response).to have_http_status :forbidden
        end
      end

      context 'when payload is not an object' do
        let(:payload) { '[]' }
        let(:signature) { "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), Settings.github.secret_key, payload)}" }

        it 'should return error' do
          post('/api/v2/github/push', params: payload, headers: { 'HTTP_X_HUB_SIGNATURE' => signature, 'CONTENT_TYPE' => 'application/json' })
          expect(response).to have_http_status :bad_request
        end
      end

      context 'when payload contains Oj object mode keys' do
        let(:payload) do
          Oj.dump(
            {
              repository: { name: 'repository', owner: { name: 'owner' }, pushed_at: 'pushed_at' },
              ref: 'refs/heads/xxx',
              head_commit: { url: 'url', author: { username: { '^o' => 'Object' } } }
            },
            mode: :compat
          )
        end
        let(:signature) { "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), Settings.github.secret_key, payload)}" }

        it 'should parse them as plain hash' do
          allow(Github::DeployWorker).to receive(:perform_async)

          post('/api/v2/github/push', params: payload, headers: { 'HTTP_X_HUB_SIGNATURE' => signature, 'CONTENT_TYPE' => 'application/json' })

          expect(response).to have_http_status :created
          key = Genova::Sidekiq::JobStore.send(:generate_key, 'pushed_at:pushed_at')
          expect(Genova::RedisPool.get.get(key)).to include('"author":{"^o":"Object"}')
        end
      end
    end

    describe 'POST /api/v2/github/actions/push' do
      let(:actions_pushed_commit) do
        Oj.dump(
          {
            account: 'account',
            repository: 'repository',
            ref: 'refs/heads/xxx',
            commit_url: 'url',
            author: 'author',
            pushed_at: 'pushed_at'
          },
          mode: :compat
        )
      end

      let(:actions_pushed_tag) do
        Oj.dump(
          {
            account: 'account',
            repository: 'repository',
            ref: 'refs/tags/xxx',
            commit_url: 'url',
            author: 'author',
            pushed_at: 'pushed_at'
          },
          mode: :compat
        )
      end

      context 'when valid secret key' do
        let(:headers) { { 'HTTP_X_GITHUB_SECRET_KEY' => Settings.github.secret_key, 'CONTENT_TYPE' => 'application/json' } }

        context 'when branch is pushed' do
          it 'should return success' do
            allow(Github::DeployWorker).to receive(:perform_async)
            post('/api/v2/github/actions/push', params: actions_pushed_commit, headers:)
            expect(response).to have_http_status :created
          end
        end

        context 'when tag is pushed' do
          it 'should return error' do
            allow(Github::DeployWorker).to receive(:perform_async)
            post('/api/v2/github/actions/push', params: actions_pushed_tag, headers:)
            expect(response).to have_http_status :forbidden
          end
        end
      end

      context 'when invalid secret key' do
        let(:headers) { { 'HTTP_X_GITHUB_SECRET_KEY' => 'invalid_secret_key', 'CONTENT_TYPE' => 'application/json' } }

        it 'should return error' do
          allow(Github::DeployWorker).to receive(:perform_async)
          post('/api/v2/github/actions/push', params: actions_pushed_commit, headers:)
          expect(response).to have_http_status :forbidden
        end

        it 'should not parse payload' do
          allow(Oj).to receive(:load).and_call_original

          post('/api/v2/github/actions/push', params: actions_pushed_commit, headers:)

          expect(Oj).not_to have_received(:load)
        end
      end
    end
  end
end
