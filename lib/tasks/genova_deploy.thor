class GenovaDeploy < Thor
  class_option :account, default: Settings.github.account, desc: 'GitHub account name'
  class_option :branch, default: Settings.github.default_branch, aliases: :b, desc: 'Branch name.'
  class_option :force, default: false, type: :boolean, aliases: :f, desc: 'Ignore deploy lock and force deploy.'
  class_option :interactive, default: false, type: :boolean, aliases: :i, desc: 'Prompt before exectuion.'
  class_option :ssh_secret_key_path, desc: 'Private key for retrieving repository.'
  class_option :verbose, default: false, type: :boolean, aliases: :v, desc: 'Output verbose log.'

  no_commands do
    def deploy(options)
      return if options[:interactive] && !HighLine.new.agree('> Do you want to deploy? (y/n): ', '')

      if options[:target].present?
        manager = ::Genova::Git::RepositoryManager.new(options[:account], options[:repository], options[:branch])
        options.merge!(manager.load_deploy_config.target(options[:target]))
      end

      deploy_job = DeployJob.new(
        mode: DeployJob.mode.find_value(:manual).to_sym,
        account: options[:account],
        branch: options[:branch],
        cluster: options[:cluster],
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
  option :cluster, required: true, aliases: :c, desc: 'Cluster name.'
  option :run_task, required: true, aliases: :t, desc: 'Task name.'
  option :repository, required: true, aliases: :r, desc: 'Repository name.'
  def run_task
    hash_options = options.to_hash.symbolize_keys
    hash_options[:type] = DeployJob.type.find_value(:run_task)

    deploy(hash_options)
  end

  desc 'service', 'Deploy service to ECS'
  option :cluster, aliases: :c, desc: 'Cluster name.'
  option :repository, required: true, aliases: :r, desc: 'Repository name.'
  option :service, required: true, aliases: :s, desc: 'Service name.'
  option :target, aliases: :t, desc: 'Deploy by specifying target.'
  def service
    hash_options = options.to_hash.symbolize_keys
    hash_options[:type] = DeployJob.type.find_value(:service)

    deploy(hash_options)
  end

  desc 'scheduled-task', 'Deploy scheduled task to ECS'
  option :cluster, aliases: :c, desc: 'Cluster name.'
  option :scheduled_task_rule, required: true, desc: 'Schedule rule name.'
  option :scheduled_task_target, required: true, desc: 'Schedule target name.'
  option :repository, required: true, aliases: :r, desc: 'Repository name.'
  option :target, aliases: :t, desc: 'Deploy by specifying target.'
  def scheduled_task
    hash_options = options.to_hash.symbolize_keys
    hash_options[:type] = DeployJob.type.find_value(:scheduled_task)

    deploy(hash_options)
  end
end
