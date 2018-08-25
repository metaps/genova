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
  option :profile, required: false, default: Settings.aws.profile, desc: 'AWS profile.'
  option :region, required: false, default: Settings.aws.region, desc: 'Specify ECR region.'
  option :repository, required: true, aliases: :r, desc: 'GitHub repository.'
  option :ssh_secret_key_path, required: false, default: "#{ENV.fetch('HOME')}/.ssh/id_rsa", desc: 'Private key for accessing GitHub.'
  option :verbose, required: false, default: false, type: :boolean, aliases: :v, desc: 'Output verbose log.'
  option :force, required: false, default: false, type: :boolean, aliases: :f, desc: 'Ignore deploy lock and force deploy.'
  def deploy
    return if options[:interactive] && !HighLine.new.agree('> Do you want to run? (y/n): ', '')

    client = ::Genova::Client.new(options.symbolize_keys)
    client.run
  end

  desc 'debug-slack-greeting', 'Slack bot says Hello'
  def debug_slack_greeting
    ::Genova::Slack::Bot.new.post_simple_message(message: 'Hello')
    @logger.info('Sent message.')
  end

  desc 'debug-github-push', 'Emulate GitHub push'
  option :account, required: false, default: Settings.github.account, desc: 'GitHub account'
  option :repository, required: true, aliases: :r, desc: 'Source repository.'
  option :branch, required: false, default: Settings.github.default_branch, aliases: :b, desc: 'Source branch.'
  def debug_github_push
    post_data = {
      repository: {
        full_name: "#{account}/#{options[:repository]}"
      },
      ref: "refs/heads/#{options[:branch]}"
    }

    payload_body = Oj.dump(post_data)
    sha1 = OpenSSL::Digest.new('sha1')
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(sha1, ENV.fetch('GITHUB_SECRET_KEY'), payload_body)

    headers = { x_hub_signature: signature }
    result = RestClient.post('http://rails:3000/api/v1/github/push', payload_body, headers)

    @logger.info('Sent deploy notification to Slack.')
    @logger.info(result)
  end

  desc 'debug-update-source', 'Retrieve latest source'
  option :account, required: false, default: Settings.github.account, desc: 'GitHub account'
  option :repository, required: true, aliases: :r, desc: 'Source repository.'
  option :branch, required: false, default: Settings.github.default_branch, aliases: :b, desc: 'Source branch.'
  def debug_update_source
    manager = ::Genova::Git::LocalRepositoryManager.new(options[:account], options[:repository], options[:branch])
    manager.update
  end
end
