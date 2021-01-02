module V2
  class GithubRoutes < Grape::API
    helpers Helper::GithubHelper

    # /api/v2/github
    resource :github do
      before do
        @payload_body = request.body.read
        error! 'Signature is invalid.', 403 unless verify_signature?(@payload_body)
      end

      # POST /api/v2/github/push
      post :push do
        result = parse(@payload_body)

        id = Genova::Sidekiq::Queue.add(
          account: result[:account],
          repository: result[:repository],
          branch: result[:branch]
        )
        Github::DeployWorker.perform_async(id)

        { result: 'Deploy request was executed.' }
      rescue Genova::Exceptions::InvalidRequestError => e
        { result: e.message }
      end
    end
  end
end
