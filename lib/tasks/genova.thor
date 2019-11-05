module GenovaCli
  class Deploy < Thor
    class_option :account, default: ENV.fetch('GITHUB_ACCOUNT', Settings.github.account), desc: 'GitHub account name'
    class_option :branch, default: Settings.github.default_branch, aliases: :b, desc: 'Branch name.'
    class_option :force, default: false, type: :boolean, aliases: :f, desc: 'Ignore deploy lock and force deploy.'
    class_option :interactive, default: false, type: :boolean, aliases: :i, desc: 'Prompt before exectuion.'
    class_option :ssh_secret_key_path, desc: 'Private key for retrieving repository.'
    class_option :verbose, default: false, type: :boolean, aliases: :v, desc: 'Output verbose log.'

    no_commands do
      def deploy(options)
        return if options[:interactive] && !HighLine.new.agree('> Do you want to deploy? (y/n): ', '')

        code_manager = ::Genova::CodeManager::Git.new(options[:account], options[:repository], options[:branch]) if options[:repository].present?

        options.merge!(code_manager.load_deploy_config.target(options[:target])) if options[:target].present?
        repository = Genova::Config::SettingsHelper.find_repository(options[:repository])

        deploy_job = DeployJob.new(
          mode: DeployJob.mode.find_value(:manual).to_sym,
          type: options[:type],
          account: options[:account],
          branch: options[:branch],
          cluster: options[:cluster],
          base_path: repository[:base_path],
          service: options[:service],
          scheduled_task_rule: options[:scheduled_task_rule],
          scheduled_task_target: options[:scheduled_task_target],
          repository: options[:repository],
          ssh_secret_key_path: options[:ssh_secret_key_path],
          run_task: options[:run_task]
        )

        extra = {
          interactive: options[:interactive],
          verbose: options[:verbose],
          force: options[:force]
        }

        ::Genova::Client.new(deploy_job, extra).run
      end
    end

    desc 'run-task', 'Deploy run task to ECS'
    option :cluster, aliases: :c, default: 'default', desc: 'Cluster name.'
    option :run_task, desc: 'Task name.'
    option :repository, required: true, aliases: :r, desc: 'Repository or alias name.'
    option :target, aliases: :t, desc: 'Deploy by specifying target.'
    def run_task
      raise Genova::Exceptions::InvalidArgumentError, 'Task or target must be specified.' if options[:run_task].blank? && options[:target].blank?

      hash_options = options.to_hash.symbolize_keys
      hash_options[:type] = DeployJob.type.find_value(:run_task)

      deploy(hash_options)
    end

    desc 'service', 'Deploy service to ECS'
    option :cluster, aliases: :c, default: 'default', desc: 'Cluster name.'
    option :repository, required: true, aliases: :r, desc: 'Repository or alias name.'
    option :service, aliases: :s, desc: 'Service name.'
    option :target, aliases: :t, desc: 'Deploy by specifying target.'
    def service
      raise Genova::Exceptions::InvalidArgumentError, 'Service or target must be specified.' if options[:service].blank? && options[:target].blank?

      hash_options = options.to_hash.symbolize_keys
      hash_options[:type] = DeployJob.type.find_value(:service)

      deploy(hash_options)
    end

    desc 'scheduled-task', 'Deploy scheduled task to ECS'
    option :cluster, aliases: :c, default: 'default', desc: 'Cluster name.'
    option :scheduled_task_rule, desc: 'Schedule rule name.'
    option :scheduled_task_target, desc: 'Schedule target name.'
    option :repository, required: true, aliases: :r, desc: 'Repository or alias name.'
    option :target, aliases: :t, desc: 'Deploy by specifying target.'
    def scheduled_task
      raise Genova::Exceptions::InvalidArgumentError, 'Scheduled task or target must be specified.' if (options[:scheduled_task_rule].blank? || options[:scheduled_task_target].blank?) && options[:target].blank?

      hash_options = options.to_hash.symbolize_keys
      hash_options[:type] = DeployJob.type.find_value(:scheduled_task)

      deploy(hash_options)
    end
  end

  class Env < Thor
    desc 'encrypt', 'Encrypt value.'
    option :master_key, required: true, desc: 'KMS Master key for encryption.'
    option :value, required: true, desc: 'Value to encrypt.'
    def encrypt
      cipher = Genova::Utils::Cipher.new
      value = cipher.encrypt(options[:master_key], options[:value])

      puts "Encrypted value: #{value}"
    end

    desc 'decrypt', 'Decrypt value.'
    option :value, required: true, desc: 'Value to decrypt.'
    def decrypt
      cipher = Genova::Utils::Cipher.new
      value = cipher.decrypt(options[:value])

      puts "Decrypted value: #{value}"
    end
  end

  class Debug < Thor
    desc 'slack-greeting', 'Slack bot says Hello'
    def slack_greeting
      ::Genova::Slack::Bot.new.post_simple_message(text: 'Hello')
    end

    desc 'emulate-github-push', 'Emulate GitHub push'
    option :account, required: false, default: ENV.fetch('GITHUB_ACCOUNT', Settings.github.account), desc: 'GitHub account'
    option :repository, required: true, aliases: :r, desc: 'Source repository.'
    option :branch, required: false, default: Settings.github.default_branch, aliases: :b, desc: 'Source branch.'
    def emulate_github_push
      post_data = {
        repository: {
          full_name: "#{options[:account]}/#{options[:repository]}"
        },
        ref: "refs/heads/#{options[:branch]}"
      }

      payload_body = Oj.dump(post_data)
      sha1 = OpenSSL::Digest.new('sha1')
      signature = 'sha1=' + OpenSSL::HMAC.hexdigest(sha1, ENV.fetch('GITHUB_SECRET_KEY'), payload_body)

      headers = { x_hub_signature: signature }
      result = RestClient.post('http://rails:3000/api/v1/github/push', payload_body, headers)

      puts 'Sent deploy notification to Slack.'
      puts result
    end

    desc 'git-pull', 'Retrieve latest source'
    option :account, required: false, default: ENV.fetch('GITHUB_ACCOUNT', Settings.github.account), desc: 'GitHub account'
    option :repository, required: true, aliases: :r, desc: 'Source repository.'
    option :branch, required: false, default: Settings.github.default_branch, aliases: :b, desc: 'Source branch.'
    def git_pull
      code_manager = ::Genova::CodeManager::Git.new(options[:account], options[:repository], options[:branch])
      puts "Commit ID: #{code_manager.pull}"
    end
  end

  class Default < Thor
    namespace :genova

    desc 'deploy', 'Deploy application to ECS.'
    subcommand 'deploy', Deploy

    desc 'env', 'Environment variable encryption and decryption.'
    subcommand 'env', Env

    desc 'debug', 'Debug genova'
    subcommand 'debug', Debug

    desc 'docker-cleanup', 'Delete old containers and images. This program is running on Genova.'
    def docker_cleanup
      ::Genova::Docker::Cleaner.execute
    end

    desc 'register-task', 'Register task definition.'
    option :account, default: ENV.fetch('GITHUB_ACCOUNT', Settings.github.account), desc: 'GitHub account name'
    option :branch, default: Settings.github.default_branch, aliases: :b, desc: 'Branch name.'
    option :path, required: true, desc: 'Task path.'
    option :repository, required: true, aliases: :r, desc: 'Repository name.'
    def register_task
      code_manager = ::Genova::CodeManager::Git.new(options[:account], options[:repository], options[:branch])
      code_manager.pull

      path = code_manager.task_definition_config_path(options[:path])
      task = Genova::Ecs::Task::Client.new.register(path, tag: 'latest')

      puts("Registered task. [#{task.task_definition_arn}]")
    end

    desc 'version', 'Show version'
    def version
      puts "genova #{Genova::VERSION::STRING}"
    end
  end
end
