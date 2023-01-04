require 'rails_helper'

module V2
  describe GithubRoutes do
    describe 'POST /api/v2/github/push' do
      let(:webhook_pushed_commit) do
        Oj.dump(
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
        )
      end

      let(:webhook_pushed_tag) do
        Oj.dump(
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
        )
      end

      before do
        allow(Settings.github).to receive(:secret_key).and_return('')

        remove_key = Genova::Sidekiq::JobStore.send(:generate_key, 'pushed_at:pushed_at')
        Redis.current.del(remove_key)
      end

      context 'when valid signature' do
        digest = OpenSSL::Digest.new('sha1')

        context 'when branch is pushed' do
          let(:signature) { "sha1=#{OpenSSL::HMAC.hexdigest(digest, Settings.github.secret_key, webhook_pushed_commit)}" }
          let(:headers) { { 'HTTP_X_HUB_SIGNATURE' => signature, 'HTTP_CONTENT_TYPE' => 'application/json' } }

          it 'should be return success' do
            allow(Github::DeployWorker).to receive(:perform_async)
            post '/api/v2/github/push', params: webhook_pushed_commit, headers: headers
            expect(response).to have_http_status :created
          end
        end

        context 'when tag is pushed' do
          let(:signature) { "sha1=#{OpenSSL::HMAC.hexdigest(digest, Settings.github.secret_key, webhook_pushed_tag)}" }
          let(:headers) { { 'HTTP_X_HUB_SIGNATURE' => signature, 'HTTP_CONTENT_TYPE' => 'application/json' } }

          it 'should be return error' do
            allow(Github::DeployWorker).to receive(:perform_async)
            post '/api/v2/github/push', params: webhook_pushed_tag, headers: headers
            expect(response).to have_http_status :forbidden
          end
        end
      end

      context 'when invalid signature' do
        let(:signature) { 'sha1=invalid_signature' }
        let(:headers) { { 'HTTP_X_HUB_SIGNATURE' => signature, 'HTTP_CONTENT_TYPE' => 'application/json' } }

        it 'should be return error' do
          post '/api/v2/github/push', params: webhook_pushed_commit, headers: headers
          expect(response).to have_http_status :forbidden
        end
      end
    end

    describe 'POST /api/v2/github/actions/push' do
      let(:actions_pushed_commit) do
        Oj.dump(
          account: 'account',
          repository: 'repository',
          ref: 'refs/heads/xxx',
          commit_url: 'url',
          author: 'author',
          pushed_at: 'pushed_at'
        )
      end

      let(:actions_pushed_tag) do
        Oj.dump(
          account: 'account',
          repository: 'repository',
          ref: 'refs/tags/xxx',
          commit_url: 'url',
          author: 'author',
          pushed_at: 'pushed_at'
        )
      end

      context 'when valid secret key' do
        let(:headers) { { 'HTTP_X_GITHUB_SECRET_KEY' => Settings.github.secret_key } }

        context 'when branch is pushed' do
          it 'should be return success' do
            allow(Github::DeployWorker).to receive(:perform_async)
            post '/api/v2/github/actions/push', params: actions_pushed_commit, headers: headers
            expect(response).to have_http_status :created
          end
        end

        context 'when tag is pushed' do
          it 'should be return error' do
            allow(Github::DeployWorker).to receive(:perform_async)
            post '/api/v2/github/actions/push', params: actions_pushed_tag, headers: headers
            expect(response).to have_http_status :forbidden
          end
        end
      end

      context 'when invalid secret key' do
        let(:headers) { { 'HTTP_X_GITHUB_SECRET_KEY' => 'invalid_secret_key' } }

        it 'should be return error' do
          allow(Github::DeployWorker).to receive(:perform_async)
          post '/api/v2/github/actions/push', params: actions_pushed_commit, headers: headers
          expect(response).to have_http_status :forbidden
        end
      end
    end
  end
end
