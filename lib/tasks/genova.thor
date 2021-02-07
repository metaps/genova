module GenovaCli
  class Deploy < Thor
    class_option :branch, aliases: :b, desc: 'Branch to deploy.'
    class_option :force, default: false, type: :boolean, aliases: :f, desc: 'If true is specified, it forces a deployment.'
    class_option :interactive, default: false, type: :boolean, aliases: :i, desc: 'Show confirmation message before deploying.'
    class_option :ssh_secret_key_path, desc: 'SSH key to use when retrieving repository.'
    class_option :tag, desc: 'Tag to deploy.'
    class_option :verbose, default: false, type: :boolean, aliases: :v, desc: 'Outputting detailed logs.'

    no_commands do
      def prepare(options)
        options[:branch] = Settings.github.default_branch if options[:branch].nil? && options[:tag].nil?
        return if options[:repository].nil? || options[:target].nil?

        code_manager = ::Genova::CodeManager::Git.new(
          ENV.fetch('GITHUB_ACCOUNT'),
          options[:repository],
          branch: options[:branch],
          tag: options[:tag]
        )
        options.merge!(code_manager.load_deploy_config.find_target(options[:target]))
      end

      def deploy(options)
        return if options[:interactive] && !HighLine.new.agree('> Do you want to deploy? (y/n): ', '')

        prepare(options)
        repository_settings = Genova::Config::SettingsHelper.find_repository(options[:repository])

        deploy_job = DeployJob.new(
          mode: DeployJob.mode.find_value(:manual).to_sym,
          type: options[:type],
          alias: repository_settings[:alias],
          account: ENV.fetch('GITHUB_ACCOUNT'),
          branch: options[:branch],
          tag: options[:tag],
          cluster: options[:cluster],
          service: options[:service],
          scheduled_task_rule: options[:scheduled_task_rule],
          scheduled_task_target: options[:scheduled_task_target],
          repository: repository_settings[:name] || options[:repository],
          ssh_secret_key_path: options[:ssh_secret_key_path],
          run_task: options[:run_task],
          override_container: options[:override_container],
          override_command: options[:override_command]
        )

        extra = {
          interactive: options[:interactive],
          verbose: options[:verbose],
          force: options[:force]
        }

        ::Genova::Client.new(deploy_job, extra).run
      end
    end

    desc 'run-task', 'Execute run task'
    option :cluster, aliases: :c, default: 'default', desc: 'Cluster to deploy.'
    option :override_container, desc: 'Container name to override'
    option :override_command, desc: 'Command to override'
    option :run_task, desc: 'Name of task to execute.'
    option :repository, required: true, aliases: :r, desc: 'Repository name or alias name.'
    option :target, aliases: :t, desc: 'Target to deploy. (https://github.com/metaps/genova/wiki/Deploy-target)'
    def run_task
      raise Genova::Exceptions::InvalidArgumentError, 'Task or target must be specified.' if options[:run_task].blank? && options[:target].blank?

      hash_options = options.to_hash.symbolize_keys
      hash_options[:type] = DeployJob.type.find_value(:run_task)

      deploy(hash_options)
    end

    desc 'service', 'Deploy service to ECS'
    option :cluster, aliases: :c, default: 'default', desc: 'Cluster to deploy.'
    option :repository, required: true, aliases: :r, desc: 'Repository name or alias name.'
    option :service, aliases: :s, desc: 'Service to deploy.'
    option :target, aliases: :t, desc: 'Target to deploy. (https://github.com/metaps/genova/wiki/Deploy-target)'
    def service
      raise Genova::Exceptions::InvalidArgumentError, 'Service or target must be specified.' if options[:service].blank? && options[:target].blank?

      hash_options = options.to_hash.symbolize_keys
      hash_options[:type] = DeployJob.type.find_value(:service)

      deploy(hash_options)
    end

    desc 'scheduled-task', 'Deploy scheduled task to ECS'
    option :cluster, aliases: :c, default: 'default', desc: 'Cluster to deploy.'
    option :scheduled_task_rule, desc: 'Schedule rule to deploy.'
    option :scheduled_task_target, desc: 'Schedule target to deploy.'
    option :repository, required: true, aliases: :r, desc: 'Repository name or alias name.'
    option :target, aliases: :t, desc: 'Target to deploy. (https://github.com/metaps/genova/wiki/Deploy-target)'
    def scheduled_task
      raise Genova::Exceptions::InvalidArgumentError, 'Scheduled task or target must be specified.' if (options[:scheduled_task_rule].blank? || options[:scheduled_task_target].blank?) && options[:target].blank?

      hash_options = options.to_hash.symbolize_keys
      hash_options[:type] = DeployJob.type.find_value(:scheduled_task)

      deploy(hash_options)
    end
  end

  class Env < Thor
    desc 'encrypt', 'Encrypt argument values with KMS.'
    option :master_key, required: true, desc: 'KMS master key used for encryption.'
    option :value, required: true, desc: 'Strings to encrypt'
    def encrypt
      cipher = Genova::Utils::Cipher.new
      value = cipher.encrypt(options[:master_key], options[:value])

      puts "Encrypted value: #{value}"
    end

    desc 'decrypt', 'Decrypt KMS encrypted values.'
    option :value, required: true, desc: 'Strings to decrypt'
    def decrypt
      cipher = Genova::Utils::Cipher.new
      value = cipher.decrypt(options[:value])

      puts "Decrypted value: #{value}"
    end
  end

  class Debug < Thor
    desc 'slack-greeting', 'Slack bot says Hello'
    def slack_greeting
      Genova::Slack::Interactive::Bot.new.send_message('Hello')
    end

    desc 'emulate-github-push', 'Emulate GitHub push'
    option :repository, required: true, aliases: :r, desc: 'Source repository.'
    option :branch, aliases: :b, desc: 'Source branch.'
    def emulate_github_push
      post_data = {
        repository: {
          full_name: "#{ENV.fetch('GITHUB_ACCOUNT')}/#{options[:repository]}"
        },
        ref: "refs/heads/#{options[:branch]}"
      }

      payload_body = Oj.dump(post_data)
      digest = OpenSSL::Digest.new('sha1')
      signature = "sha1=#{OpenSSL::HMAC.hexdigest(digest, ENV.fetch('GITHUB_SECRET_KEY'), payload_body)}"

      headers = { x_hub_signature: signature }
      result = RestClient.post('http://rails:3000/api/v1/github/push', payload_body, headers)

      puts 'Sent deploy notification to Slack.'
      puts result
    end
  end

  class Default < Thor
    namespace :genova

    desc 'deploy', 'Deploy application to ECS.'
    subcommand 'deploy', Deploy

    desc 'env', 'It supports encryption and compounding using KMS.'
    subcommand 'env', Env

    desc 'debug', 'Debug genova'
    subcommand 'debug', Debug

    desc 'docker-cleanup', 'Deletes unused containers, images, networks, and volumes built with genova.'
    def docker_cleanup
      ::Genova::Docker::Cleaner.execute
    end

    desc 'register-task', 'Register task definition.'
    option :branch, default: Settings.github.default_branch, aliases: :b, desc: 'Branch name.'
    option :path, required: true, desc: 'Task path.'
    option :repository, required: true, aliases: :r, desc: 'Repository name.'
    def register_task
      code_manager = ::Genova::CodeManager::Git.new(ENV.fetch('GITHUB_ACCOUNT'), options[:repository], branch: options[:branch])
      code_manager.pull

      path = code_manager.task_definition_config_path(options[:path])
      task = Genova::Ecs::Task::Client.new.register(path, tag: 'latest')

      puts("Registered task. [#{task.task_definition_arn}]")
    end

    desc 'version2', 'Show version'
    def version2
DeployJob.create({
  id: Time.now.utc.strftime('%Y%m%d-%H%M%S'),
  type: 'scheduled_task',
  status: 'success',
  mode: 'manual',
  account: 'naomichi-y',
  repository: 'reshine-api',
  tag: 'test',
  cluster: 'staging-api',
  scheduled_task_rule: 'rule1',
  scheduled_task_target: 'target1'
})

    end

    desc 'version', 'Show version'
    def version
DeployJob.create({
  id: Time.now.utc.strftime('%Y%m%d-%H%M%S'),
  type: 'service',
  status: 'success',
  mode: 'manual',
  account: 'naomichi-y',
  repository: 'reshine-api',
  tag: 'test',
  cluster: 'staging-api',
  service: 'backend5'
})

#      puts "genova #{Genova::Version::LONG_STRING}"
    end
  end
end
