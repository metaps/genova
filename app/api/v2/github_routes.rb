module V2
  class GithubRoutes < Grape::API
    helpers Helper::GithubHelper

    # /api/v2/github
    resource :github do
      before do
        @payload = request.body.read
        @data = Oj.load(@payload, symbol_keys: true)
      end

      # POST /api/v2/github/push
      post :push do
        error! 'Signature is invalid.', 403 unless verify_webhook_signature?(@payload)

        id = Genova::Sidekiq::JobStore.create(parse_webhook_data(@data))
        Github::DeployWorker.perform_async(id)

        { result: 'Deploy request was executed.' }
      rescue Genova::Exceptions::InvalidRequestError => e
        error! e.message, 403
      end

      # /api/v2/github/actions
      resource :actions do
        # POST /api/v2/github/actions/push
        post :push do
          error! 'Secret key is invalid.', 403 unless verify_actions_secret_key?

          id = Genova::Sidekiq::JobStore.create(parse_actions_payload(@data))
          Github::DeployWorker.perform_async(id)

          { result: 'Deploy request was executed.' }
        rescue Genova::Exceptions::InvalidRequestError => e
          error! e.message, 403
        end
      end
    end
  end
end
