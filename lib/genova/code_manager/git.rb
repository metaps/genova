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
  module CodeManager
    class Git
      attr_reader :repos_path, :base_path

      def initialize(account, repository, branch = Settings.github.default_branch, options = {})
        @account = account
        @branch = branch
        @logger = options[:logger] || ::Logger.new(nil)
        @repository = repository
        @repos_path = Rails.root.join('tmp', 'repos', @account, @repository).to_s

        param = Settings.github.repositories.find do |k, _v|
          k[:name] == repository
        end

        @base_path = param.nil? ? @repos_path : Pathname(@repos_path).join(param[:base_path] || '').to_s
      end

      def clone
        return if File.exist?("#{@repos_path}/.git/config")

        FileUtils.rm_rf(@repos_path)

        uri = Genova::Github::Client.new(@account, @repository).build_clone_uri
        @logger.info("Git clone: #{uri}")

        FileUtils.mkdir_p(@repos_path) unless Dir.exist?(@repos_path)
        ::Git.clone(uri, '', path: @repos_path)
      end

      def pull
        clone

        @logger.info("Git checkout: #{@branch}")

        git = client
        git.fetch
        git.clean(force: true, d: true)
        git.checkout(@branch) if git.branch != @branch
        git.reset_hard("origin/#{@branch}")

        git.log(1).to_s
      end

      def load_deploy_config
        pull

        path = Pathname(@base_path).join('config/deploy.yml')
        raise Exceptions::ValidationError, "File does not exist. [#{path}]" unless File.exist?(path)

        params = YAML.load(File.read(path)).deep_symbolize_keys
        Config::DeployConfig.new(params)
      end

      def task_definition_config_path(path)
        Pathname(@base_path).join(path).to_s
      end

      def load_task_definition_config(path)
        path = task_definition_config_path(path)
        raise Exceptions::ValidationError, "File does not exist. [#{path}]" unless File.exist?(path)

        params = YAML.load(File.read(path)).deep_symbolize_keys
        Config::TaskDefinitionConfig.new(params)
      end

      def origin_branches
        clone

        git = client
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

        git = client
        git.fetch
        git.remote.branch(@branch).gcommit.log(1).first
      end

      def find_commit_id(tag)
        git = client
        git.fetch
        git.tag(tag)
      rescue ::Git::GitTagNameDoesNotExist
        nil
      end

      def release(tag, commit_id)
        pull

        git = client
        git.add_tag(tag, commit_id)
        git.push('origin', @branch, tags: tag)
      end

      private

      def client
        ::Git.open(@repos_path, log: @logger)
      end
    end
  end
end
