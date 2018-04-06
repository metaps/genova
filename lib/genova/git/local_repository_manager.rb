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
      attr_reader :path
      class_attribute :logger

      def initialize(account, repository, branch = Settings.github.default_branch)
        @account = account
        @repository = repository
        @branch = branch
        @path = Rails.root.join('tmp', 'repos', @account, @repository).to_s

        Genova::Git::LocalRepositoryManager.logger = Logger.new(STDOUT) if Genova::Git::LocalRepositoryManager.logger.nil?
      end

      def clone
        return if Dir.exist?("#{@path}/.git")
        uri = "git@github.com:#{@account}/#{@repository}.git"

        FileUtils.mkdir_p(@path) unless Dir.exist?(@path)
        ::Git.clone(uri, '', path: @path)
      end

      def update
        clone

        git = git_client
        git.fetch
        git.clean(force: true, d: true)
        git.checkout(@branch) if git.branch != @branch
        git.reset_hard("origin/#{@branch}")
      end

      def open_deploy_config
        clone

        path = Pathname(@path).join('config/deploy.yml')

        params = YAML.load(File.read(path)).deep_symbolize_keys
        Genova::Config::DeployConfig.new(params)
      end

      def task_definition_config_path(service)
        Pathname(@path).join('config', 'deploy', "#{service}.yml").to_s
      end

      def open_task_definition_config(service)
        clone

        params = YAML.load(File.read(task_definition_config_path(service))).deep_symbolize_keys
        Genova::Config::TaskDefinitionConfig.new(params)
      end

      def origin_branches
        clone

        branches = []
        git_client.branches.remote.each do |branch|
          next if branch.name.include?('->')
          branches << branch
        end

        branches
      end

      def origin_last_commit_id
        clone

        git = git_client
        git.fetch
        git.log('-remotes=origin').first
      end

      private

      def git_client
        ::Git.open(@path, log: Genova::Git::LocalRepositoryManager.logger)
      end
    end
  end
end
