module V1
  class GithubRoutes < Grape::API
    helpers Helper::GithubHelper

    # /api/v1/github
    resource :github do
      before do
        @payload_body = request.body.read
        error! 'Signature is invalid.', 403 unless verify_signature?(@payload_body)
      end

      # POST /api/v1/github/push
      post :push do
        begin
          result = parse(@payload_body)

          id = Genova::Sidekiq::Queue.add(
            account: result[:account],
            repository: result[:repository],
            branch: result[:branch]
          )
          Github::DeployWorker.perform_async(id)

          { result: 'Deploy request was executed.' }

        rescue Helper::GithubHelper::ParseError
          error! e.message, 403
        end
      end
    end
  end
end
