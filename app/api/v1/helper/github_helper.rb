module V1
  module Helper
    module GithubHelper
      extend Grape::API::Helpers

      def verify_signature?(payload_body)
        return false unless request.env['HTTP_X_HUB_SIGNATURE']

        sha1 = OpenSSL::Digest.new('sha1')
        signature = 'sha1=' + OpenSSL::HMAC.hexdigest(sha1, ENV.fetch('GITHUB_SECRET_KEY'), payload_body)
        payload_body.present? && Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
      end

      def parse(payload_body)
        data = Oj.load(payload_body, symbol_keys: true)
        full_name = data[:repository][:full_name].split('/')

        result = {
          account: full_name[0],
          repository: full_name[1]
        }
        result[:branch] = data[:ref].slice(11..data[:ref].size) if data[:ref].present?
        result
      end

      def detect_auto_deploy_service(account, repository, branch)
        deploy_config = load_deploy_config(account, repository, branch)
        auto_deploy = deploy_config.dig(:auto_deploy)

        return nil if auto_deploy.nil?

        target = auto_deploy.find { |k, _v| k[:branch] == branch }

        {
          cluster: target[:cluster],
          service: target[:service]
        }
      end

      def create_deploy_job(params)
        id = DeployJob.generate_id
        DeployJob.create(id: id,
                         status: Genova::Client.status.find_value(:in_progress).to_s,
                         mode: Genova::Client.mode.find_value(:auto).to_s,
                         account: params[:account],
                         repository: params[:repository],
                         branch: params[:branch],
                         cluster: params[:cluster],
                         service: params[:service])

        id
      end

      private

      def load_deploy_config(account, repository, branch)
        octokit = Octokit::Client.new(access_token: ENV.fetch('GITHUB_OAUTH_TOKEN'))
        resource = octokit.contents(
          "#{account}/#{repository}",
          ref: branch,
          path: 'config/deploy.yml'
        )
        YAML.load(Base64.decode64(resource.attrs[:content])).deep_symbolize_keys
      end
    end
  end
end
