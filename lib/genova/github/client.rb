module Genova
  module Github
    class Client
      def initialize(account, repository)
        @account = account
        @repository = repository
      end

      def create_tag(tag, commit_id)
        client.create_release("#{@account}/#{@repository}", tag, target_commitish: commit_id)
      end

      def find_commit_id(tag)
        release = client.release_for_tag("#{@account}/#{@repository}", tag)
        release[:target_commitish]
      end

      def build_clone_uri
        "git@github.com:#{@account}/#{@repository}.git"
      end

      def build_repository_uri
        "https://github.com/#{@account}/#{@repository}"
      end

      def build_commit_id_uri(commit_id)
        "https://github.com/#{@account}/#{@repository}/commit/#{commit_id}"
      end

      def build_tag_uri(tag)
        "https://github.com/#{@account}/#{@repository}/releases/tag/#{tag}"
      end

      def build_compare_uri(target1, target2)
        "https://github.com/#{@account}/#{@repository}/compare/#{target1}...#{target2}"
      end

      def build_branch_uri(branch)
        "https://github.com/#{@account}/#{@repository}/tree/#{branch}"
      end

      private

      def client
        oauth_token = ENV.fetch('GITHUB_OAUTH_TOKEN')
        raise RuntimeError, 'GITHUB_OAUTH_TOKEN is undefined.' if oauth_token.empty?

        Octokit::Client.new(access_token: oauth_token)
      end
    end
  end
end
