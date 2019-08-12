class Genova < Thor
  desc 'deploy', 'Deploy application to ECS.'
  subcommand 'deploy', GenovaDeploy

  desc 'debug', 'Debug genova'
  subcommand 'debug', GenovaDebug

  no_commands do
    def invoke_command(command, *args)
      @logger = Logger.new(STDOUT)

      super
    end
  end

  desc 'docker-cleanup', 'Delete old containers and images. This program is running on Genova.'
  def docker_cleanup
    ::Genova::Command::DockerCleanup.exec(@logger)
  end

  desc 'register-task', 'Register task definition.'
  option :account, default: Settings.github.account, desc: 'GitHub account name'
  option :branch, default: Settings.github.default_branch, aliases: :b, desc: 'Branch name.'
  option :path, required: true, desc: 'Task path.'
  option :repository, required: true, aliases: :r, desc: 'Repository name.'
  def register_task
    repository_manager = ::Genova::Git::RepositoryManager.new(options[:account], options[:repository], options[:branch])
    repository_manager.update
    path = repository_manager.task_definition_config_path(options[:path])
    task = EcsDeployer::Task::Client.new.register(path, tag: 'latest')

    @logger.info("Registered task. [#{task.task_definition_arn}]")
  end
end
