module Genova
  module CodeManager
    class Git
      attr_reader :repos_path, :base_path

      def initialize(repository, options = {})
        @account = Settings.github.account
        @branch = options[:branch]
        @tag = options[:tag]
        @logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
        @repository = repository
        @repos_path = Rails.root.join('tmp/repos', @account, @repository).to_s

        name_or_alias = options[:alias].present? ? options[:alias] : @repository
        @repository_config = Genova::Config::SettingsHelper.find_repository(name_or_alias)

        @base_path = @repository_config.nil? || @repository_config[:base_path].nil? ? @repos_path : Pathname(@repos_path).join(@repository_config[:base_path]).to_s

        ::Git.configure do |config|
          path = Rails.root.join('.ssh/id_rsa').to_s
          raise IOError, "File does not exist. [#{path}]" unless File.file?(path)

          config.git_ssh = Rails.root.join('.ssh/git-ssh.sh').to_s
        end
      end

      def update
        git = client

        @logger.info("Git checkout: #{@branch}")

        if @branch.present?
          checkout = @branch
          reset_hard = "origin/#{@branch}"
        else
          checkout = "refs/tags/#{@tag}"
          reset_hard = "refs/tags/#{@tag}"
        end

        git.fetch
        git.clean(force: true, d: true)
        git.checkout(checkout)
        git.reset_hard(reset_hard)
        git.submodule_update

        git.log(1).to_s
      end

      def load_deploy_config
        Genova::Config::DeployConfig.new(fetch_config('config/deploy.yml'))
      end

      def task_definition_config_path(path)
        File.expand_path(Pathname(@base_path).join(path).to_s)
      end

      def origin_branches
        git = client
        git.fetch

        branches = []

        git.branches.remote.each do |branch|
          next if branch.name.include?('->')

          branches << branch.name
        end

        branches
      end

      def origin_tags
        git = client
        git.fetch

        tags = []

        git.tags.each do |tag|
          tags << tag.name
        end

        tags
      end

      def origin_last_commit
        git = client
        git.fetch

        if @branch.present?
          git.remote.branch(@branch).gcommit.log(1).first.to_s
        else
          git.tag(@tag).sha
        end
      end

      def find_commit(tag)
        git = client
        git.fetch
        git.tag(tag).sha
      rescue ::Git::GitTagNameDoesNotExist
        nil
      end

      def release(tag, commit)
        update

        git = client
        git.add_tag(tag, commit)
        git.push('origin', @branch, tags: tag)
      end

      def default_branch
        git = client

        match = git.remote_show_origin.match(/HEAD branch:\s*(.+)/)
        return nil if match.nil?

        match[1]
      end

      private

      def fetch_config(path)
        path = Pathname(@repository_config[:base_path]).join(path).cleanpath.to_s if @repository_config.present? && @repository_config[:base_path].present?

        update
        config = File.read("#{repos_path}/#{path}")

        YAML.load(config).deep_symbolize_keys
      end

      def clone
        return if File.file?("#{@repos_path}/.git/config")

        FileUtils.rm_rf(@repos_path)
        uri = Genova::Github::Client.new(@repository).build_clone_uri
        @logger.info("Git clone: #{uri}")

        ::Git.clone(uri, '', branch: @branch, path: @repos_path, recursive: true)
      end

      def client
        clone
        ::Git.open(@repos_path, log: @logger)
      end
    end
  end
end
