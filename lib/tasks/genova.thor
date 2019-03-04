class Genova < Thor
  no_commands do
    def invoke_command(command, *args)
      @logger = Logger.new(STDOUT)
      super
    end
  end

  desc 'docker-cleanup', 'Delete old containers and images. This program is running on Genova.'
  def docker_cleanup
    ::Genova::Command::DockerCleanup.exec
  end

  desc 'deploy', 'Deploy application to ECS.'
  option :account, required: false, default: Settings.github.account, desc: 'GitHub account name'
  option :branch, required: false, default: Settings.github.default_branch, aliases: :b, desc: 'Branch name.'
  option :cluster, required: true, aliases: :c, desc: 'Cluster name.'
  option :force, required: false, default: false, type: :boolean, aliases: :f, desc: 'Ignore deploy lock and force deploy.'
  option :interactive, required: false, default: false, type: :boolean, aliases: :i, desc: 'Prompt before exectuion.'
  option :repository, required: true, aliases: :r, desc: 'Repository name.'
  option :scheduled_task_rule, required: false, desc: 'Scheduled task rule name. "--scheduled-task-target" option must be specified.'
  option :scheduled_task_target, required: false, desc: 'Scheduled task target name. "--scheduled-task-rule" option must be specified.'
  option :service, required: false, aliases: :s, desc: 'Service name. Either "--service" or "--scheduled-task-rule" option must be specified.'
  option :ssh_secret_key_path, required: false, desc: 'Private key for accessing GitHub.'
  option :verbose, required: false, default: false, type: :boolean, aliases: :v, desc: 'Output verbose log.'
  def deploy
    return if options[:interactive] && !HighLine.new.agree('> Do you want to run? (y/n): ', '')

    deploy_job = DeployJob.new(
      mode: DeployJob.mode.find_value(:manual).to_sym,
      account: options[:account],
      branch: options[:branch],
      cluster: options[:cluster],
      service: options[:service],
      scheduled_task_rule: options[:scheduled_task_rule],
      scheduled_task_target: options[:scheduled_task_target],
      repository: options[:repository],
      ssh_secret_key_path: options[:ssh_secret_key_path]
    )

    genova_options = {
      interactive: options[:interactive],
      verbose: options[:verbose],
      force: options[:force]
    }

    ::Genova::Client.new(deploy_job, genova_options).run
  end

  desc 'register-task', 'Register task definition.'
  option :account, required: false, default: Settings.github.account, desc: 'GitHub account name'
  option :branch, required: false, default: Settings.github.default_branch, aliases: :b, desc: 'Branch name.'
  option :path, required: true, desc: 'Task path.'
  option :repository, required: true, aliases: :r, desc: 'Repository name.'
  def register_task
    repository_manager = ::Genova::Git::RepositoryManager.new(options[:account], options[:repository], options[:branch])
    repository_manager.update
    path = repository_manager.task_definition_config_path(options[:path])

    client = EcsDeployer::Task::Client.new
    task = client.register(path, tag: 'latest')

    @logger.info("Registered task. [#{task.task_definition_arn}]")
  end
end
