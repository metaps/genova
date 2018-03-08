module CI
  module Github
    class Client
      def initialize(account, repository, branch)
        @octokit = Octokit::Client.new(access_token: ENV.fetch('GITHUB_OAUTH_TOKEN'))
        @account = account
        @repository = repository
        @branch = branch
      end

      def fetch_last_commit_id
        @octokit.commits("#{@account}/#{@repository}", sha: @branch)[0].attrs[:sha]
      end

      def fetch_deploy_config
        resource = @octokit.contents(
          "#{@account}/#{@repository}",
          ref: @branch,
          path: 'config/deploy.yml'
        )
        YAML.load(Base64.decode64(resource.attrs[:content])).deep_symbolize_keys
      end
    end
  end
end
