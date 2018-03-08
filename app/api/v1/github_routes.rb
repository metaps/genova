module V1
  class GithubRoutes < Grape::API
    helpers Helper::GithubHelper

    # /api/v1/github
    resource :github do
      before do
        @payload_body = request.body.read
        error! 'Signature do not match.', 403 unless verify_signature?(@payload_body)
      end

      # POST /api/v1/github/push
      post :push do
        result = parse(@payload_body)
        service = detect_auto_deploy_service(result[:account], result[:repository], result[:branch])
        return unless service.present?

        id = create_deploy_job(result[:account], result[:repository], result[:branch], service)
        jid = Github::DeployWorker.perform_async(id)

        { result: 'success', jid: jid }
      end
    end
  end
end
