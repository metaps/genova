module Genova
  module Github
    class Client
      def initialize(account, repository)
        @account = account
        @repository = repository
      end

      def build_clone_uri
        "git@github.com:#{@account}/#{@repository}.git"
      end

      def build_repository_uri
        build_uri("#{@account}/#{@repository}")
      end

      def build_commit_uri(commit_id)
        build_uri("#{@account}/#{@repository}/commit/#{commit_id}")
      end

      def build_tag_uri(tag)
        build_uri("#{@account}/#{@repository}/releases/tag/#{tag}")
      end

      def build_compare_uri(target1, target2)
        build_uri("#{@account}/#{@repository}/compare/#{target1}...#{target2}")
      end

      def build_branch_uri(branch)
        build_uri("#{@account}/#{@repository}/tree/#{branch}")
      end

      private

      def build_uri(path)
        "https://github.com/#{path}"
      end
    end
  end
end
