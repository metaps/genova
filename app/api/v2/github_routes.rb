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

        # Even if the webhook trigger is limited to Push, the deletion of a branch will be notified.
        # https://github.com/metaps/genova/issues/272
        error! 'Detect branch deletion.', 403 if @data[:deleted]

        id = "pushed_at:#{@data[:repository][:pushed_at]}"
        key = Genova::Sidekiq::JobStore.create(id, parse_webhook_data(@data))
        Github::DeployWorker.perform_async(key)

        { result: 'Deploy request was executed.' }
      rescue Genova::Exceptions::InvalidRequestError => e
        error! e.message, 403
      end

      # /api/v2/github/actions
      resource :actions do
        # POST /api/v2/github/actions/push
        post :push do
          error! 'Secret key is invalid.', 403 unless verify_actions_secret_key?

          id = "pushed_at:#{@data[:pushed_at]}"
          key = Genova::Sidekiq::JobStore.create(id, parse_actions_data(@data))
          Github::DeployWorker.perform_async(key)

          { result: 'Deploy request was executed.' }
        rescue Genova::Exceptions::InvalidRequestError => e
          error! e.message, 403
        end
      end
    end
  end
end
