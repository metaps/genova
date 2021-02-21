require 'rails_helper'

module V2
  describe GithubRoutes do
    describe 'POST /api/v2/github/push' do
      let(:commit_payload) do
        Oj.dump(
          repository: {
            full_name: 'account/repository'
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

      let(:not_belong_commit_payload) do
        Oj.dump(
          repository: {
            full_name: 'account/repository'
          },
          ref: 'refs/heads/xxx',
          head_commit: nil
        )
      end

      let(:tag_payload) do
        Oj.dump(
          repository: {
            full_name: 'account/repository'
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

      context 'when valid signature' do
        digest = OpenSSL::Digest.new('sha1')

        context 'when branch is pushed' do
          let(:signature) { "sha1=#{OpenSSL::HMAC.hexdigest(digest, ENV.fetch('GITHUB_SECRET_KEY'), commit_payload)}" }
          let(:headers) { { 'HTTP_X_HUB_SIGNATURE' => signature, 'HTTP_CONTENT_TYPE' => 'application/json' } }

          it 'should be return success' do
            allow(Github::DeployWorker).to receive(:perform_async)

            post '/api/v2/github/push', params: commit_payload, headers: headers

            expect(response).to have_http_status :created
          end
        end

        context 'when not belong commit is pushed' do
          let(:signature) { "sha1=#{OpenSSL::HMAC.hexdigest(digest, ENV.fetch('GITHUB_SECRET_KEY'), not_belong_commit_payload)}" }
          let(:headers) { { 'HTTP_X_HUB_SIGNATURE' => signature, 'HTTP_CONTENT_TYPE' => 'application/json' } }

          it 'should be return error' do
            allow(Github::DeployWorker).to receive(:perform_async)

            post '/api/v2/github/push', params: not_belong_commit_payload, headers: headers

            expect(response).to have_http_status :forbidden
          end
        end

        context 'when tag is pushed' do
          let(:signature) { "sha1=#{OpenSSL::HMAC.hexdigest(digest, ENV.fetch('GITHUB_SECRET_KEY'), tag_payload)}" }
          let(:headers) { { 'HTTP_X_HUB_SIGNATURE' => signature, 'HTTP_CONTENT_TYPE' => 'application/json' } }

          it 'should be return error' do
            allow(Github::DeployWorker).to receive(:perform_async)

            post '/api/v2/github/push', params: tag_payload, headers: headers

            expect(response).to have_http_status :forbidden
          end
        end
      end

      context 'when invalid signature' do
        let(:signature) { 'sha1=invalid_signature' }

        it 'should be return error' do
          post '/api/v2/github/push', params: commit_payload, headers: headers

          expect(response).to have_http_status :forbidden
        end
      end
    end
  end
end
