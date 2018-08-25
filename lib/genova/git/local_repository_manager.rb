module Genova
  module Git
    class LocalRepositoryManager
      attr_reader :repos_path, :base_path

      def initialize(account, repository, branch = Settings.github.default_branch, options = {})
        @account = account
        @branch = branch
        @logger = options[:logger] || ::Logger.new(STDOUT)

        param = Settings.github.repositories.find do |k, _v|
          k[:name] == repository || k[:repository] == repository
        end
        @repository = param.present? && param[:repository] || repository
        @repos_path = Rails.root.join('tmp', 'repos', @account, @repository).to_s
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

        git.log(1).to_s
      end

      def load_deploy_config
        update

        path = Pathname(@base_path).join('config/deploy.yml')
        raise Genova::Config::DeployConfigError, "File does not exist. [#{path}]" unless File.exist?(path)

        params = YAML.load(File.read(path)).deep_symbolize_keys
        Genova::Config::DeployConfig.new(params)
      end

      def task_definition_config_path(path)
        Pathname(@base_path).join('config', path).to_s
      end

      def load_task_definition_config(path)
        path = task_definition_config_path(path)
        raise Genova::Config::DeployConfigError, "File does not exist. [#{path}]" unless File.exist?(path)

        params = YAML.load(File.read(path)).deep_symbolize_keys
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

      private

      def git_client
        ::Git.open(@repos_path, log: @logger)
      end
    end
  end
end
