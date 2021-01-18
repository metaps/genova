module V2
  class GithubRoutes < Grape::API
    helpers Helper::GithubHelper

    # /api/v2/github
    resource :github do
      before do
        @payload = request.body.read
        error! 'Signature is invalid.', 403 unless verify_signature?(@payload)
      end

      # POST /api/v2/github/push
      post :push do
        id = Genova::Sidekiq::JobStore.create(parse(@payload))
        Github::DeployWorker.perform_async(id)

        { result: 'Deploy request was executed.' }
      rescue Genova::Exceptions::InvalidRequestError => e
        { result: e.message }
      end
    end
  end
end
