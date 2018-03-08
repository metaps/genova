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

        {
          account: full_name[0],
          repository: full_name[1],
          branch: data[:ref].slice(11..data[:ref].size)
        }
      end

      def detect_auto_deploy_environment(account, repository, branch)
        config = CI::Github::Client.new(account, repository, branch).fetch_deploy_config
        config.dig(:auto_deploy, :branches, branch.to_sym)
      end

      def create_deploy_job(account, repository, branch, environment)
        id = DeployJob.generate_id
        DeployJob.create(id: id,
                         status: CI::Deploy::Client.status.find_value(:in_progress).to_s,
                         mode: CI::Deploy::Client.mode.find_value(:auto).to_s,
                         account: account,
                         repository: repository,
                         branch: branch,
                         environment: environment)

        id
      end
    end
  end
end
