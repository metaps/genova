module Git
  class Lib
    alias __branches_all__ branches_all

    def branches_all
      arr = []

      # Add '--sort=--authordate' parameter
      command_lines('branch', ['-a', '--sort=-authordate']).each do |b|
        current = (b[0, 2] == '* ')
        arr << [b.gsub('* ', '').strip, current]
      end
      arr
    end

    private :__branches_all__
  end
end

module Genova
  module Git
    class LocalRepositoryManager
      attr_reader :repos_path, :base_path

      def initialize(account, repository, branch = Settings.github.default_branch, options = {})
        @account = account
        @repository = repository
        @branch = branch
        @repos_path = Rails.root.join('tmp', 'repos', @account, @repository).to_s
        @logger = options[:logger] || ::Logger.new(STDOUT)

        param = Settings.github.repositories.find { |k, _v| k[:name] == @repository }
        @base_path = param.nil? ? @repos_path : Pathname(@repos_path).join(param[:base_path] || '').to_s
      end

      def clone
        return if Dir.exist?("#{@repos_path}/.git")
        uri = "git@github.com:#{@account}/#{@repository}.git"

        FileUtils.mkdir_p(@repos_path) unless Dir.exist?(@repos_path)
        ::Git.clone(uri, '', path: @repos_path)
      end

      def update
        clone

        git = git_client
        git.fetch
        git.clean(force: true, d: true)
        git.checkout(@branch) if git.branch != @branch
        git.reset_hard("origin/#{@branch}")
      end

      def load_deploy_config
        update

        path = Pathname(@base_path).join('config/deploy.yml')
        params = YAML.load(File.read(path)).deep_symbolize_keys
        Genova::Config::DeployConfig.new(params)
      end

      def task_definition_config_path(cluster, service)
        params = load_deploy_config.cluster(cluster)
        path = params.dig(:services, service.to_sym, :path)

        return Pathname(@base_path).join('config', path).to_s if path.present?

        Pathname(@base_path).join('config', 'deploy', "#{service}.yml").to_s
      end

      def load_task_definition_config(cluster, service)
        update

        params = YAML.load(File.read(task_definition_config_path(cluster, service))).deep_symbolize_keys
        Genova::Config::TaskDefinitionConfig.new(params)
      end

      def origin_branches
        clone

        git = git_client
        git.fetch

        branches = []
        git.branches.remote.each do |branch|
          next if branch.name.include?('->')
          branches << branch
        end

        branches
      end

      # @return [Git::Object::Commit]
      def origin_last_commit_id
        clone

        git = git_client
        git.fetch
        git.remote.branch(@branch).gcommit.log(1).first
      end

      private

      def git_client
        ::Git.open(@repos_path, log: @logger)
      end
    end
  end
end
