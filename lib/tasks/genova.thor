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
  option :account, required: false, default: Settings.github.account, desc: 'GitHub account'
  option :branch, required: false, default: Settings.github.default_branch, aliases: :b, desc: 'Specify branch name.'
  option :cluster, required: true, aliases: :c, desc: 'Specify cluster.'
  option :service, required: true, aliases: :s, desc: 'Specify service.'
  option :interactive, required: false, default: false, type: :boolean, aliases: :i, desc: 'Prompt before exectuion.'
  option :repository, required: true, aliases: :r, desc: 'GitHub repository.'
  option :ssh_secret_key_path, required: false, default: "#{ENV.fetch('HOME')}/.ssh/id_rsa", desc: 'Private key for accessing GitHub.'
  option :verbose, required: false, default: false, type: :boolean, aliases: :v, desc: 'Output verbose log.'
  option :force, required: false, default: false, type: :boolean, aliases: :f, desc: 'Ignore deploy lock and force deploy.'
  def deploy
    return if options[:interactive] && !HighLine.new.agree('> Do you want to run? (y/n): ', '')

    ::Genova::Client.new(options.symbolize_keys).run
  end
end
