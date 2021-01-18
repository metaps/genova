module Git
  class Lib
    HARD_LIMIT = 100

    def branches_all
      arr = []
      count = 0

      command_lines('branch', ['-a', '--sort=-authordate']).each do |b|
        current = (b[0, 2] == '* ')
        arr << [b.gsub('* ', '').strip, current]
        count += 1

        break if count == HARD_LIMIT
      end
      arr
    end

    def tags
      arr = []
      count = 0

      command_lines('tag', ['--sort=-authordate']).each do |t|
        arr << t
        count += 1

        break if count == HARD_LIMIT
      end
      arr
    end
  end
end

module Genova
  module CodeManager
    class Git
      attr_reader :repos_path, :base_path

      def initialize(account, repository, options = {})
        @account = account
        @branch = options[:branch]
        @tag = options[:tag]
        @logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
        @repository = repository
        @repos_path = Rails.root.join('tmp', 'repos', @account, @repository).to_s
        @base_path = options[:base_path].nil? ? @repos_path : Pathname(@repos_path).join(options[:base_path]).to_s
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

        git.log(1).to_s
      end

      def load_deploy_config
        update

        path = Pathname(@base_path).join('config/deploy.yml')
        raise Exceptions::ValidationError, "File does not exist. [#{path}]" unless File.exist?(path)

        params = YAML.safe_load(File.read(path), [], [], true).deep_symbolize_keys
        Genova::Config::DeployConfig.new(params)
      end

      def task_definition_config_path(path)
        Pathname(@base_path).join(path).to_s
      end

      def load_task_definition_config(path)
        path = task_definition_config_path(path)
        raise Exceptions::ValidationError, "File does not exist. [#{path}]" unless File.exist?(path)

        params = YAML.safe_load(File.read(path), [], [], true).deep_symbolize_keys
        Genova::Config::TaskDefinitionConfig.new(params)
      end

      def origin_branches
        git = client
        branches = []

        git.branches.remote.each do |branch|
          next if branch.name.include?('->')

          branches << branch.name
        end

        branches
      end

      def origin_tags
        tags = []

        client.tags.each do |tag|
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
          puts git.tag(@tag).sha
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

      private

      def clone
        return if File.exist?("#{@repos_path}/.git/config")

        FileUtils.rm_rf(@repos_path)
        uri = Genova::Github::Client.new(@account, @repository).build_clone_uri
        @logger.info("Git clone: #{uri}")

        ::Git.clone(uri, '', path: @repos_path)
      end

      def client
        clone
        ::Git.open(@repos_path, log: @logger)
      end
    end
  end
end
