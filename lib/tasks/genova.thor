class Genova < Thor
  no_commands do
    def invoke_command(command, *args)
      @logger = Logger.new(STDOUT)
      super
    end
  end

  desc 'docker-gc', 'Delete old containers and images. This program is running on Genova.'
  def docker_gc
    id = ::Genova::Sidekiq::Queue.new.add({foo: 'bar'})
    job = ::Genova::Sidekiq::Queue.new.find(id)
    job.update(status: ::Genova::Sidekiq::Queue.status.find_value(:complete))
    job = ::Genova::Sidekiq::Queue.new.find(id)
    puts job.status
    #::Genova::Command::Docker.gc
  end

  desc 'deploy', 'Deploy application to ECS.'
  option :account, required: false, desc: 'GitHub account'
  option :branch, required: false, default: 'master', aliases: :b, desc: 'Specify branch name.'
  option :service, required: false, default: 'development', aliases: :s, desc: 'Specify service.'
  option :interactive, required: false, default: false, type: :boolean, aliases: :i, desc: 'Prompt before exectuion.'
  option :mode, required: false, default: 'manual', desc: 'Deploy mode. (auto/manual)'
  option :profile, required: false, default: 'default', desc: 'AWS profile.'
  option :push_only, required: false, default: false, type: :boolean, desc: 'Push image to ECR. Deployment will not be executed.'
  option :region, required: false, default: 'ap-northeast-1', desc: 'Specify ECR region.'
  option :repository, required: true, aliases: :r, desc: 'GitHub repository.'
  option :ssh_secret_key_path, required: false, default: "#{ENV.fetch('HOME')}/.ssh/id_rsa", desc: 'Private key for accessing GitHub.'
  option :verbose, required: false, default: false, type: :boolean, aliases: :v, desc: 'Output verbose log.'
  def deploy
    deploy_client = ::Genova::Deploy::Client.new(options[:mode].to_sym, options[:repository], options.symbolize_keys)
    return if options[:interactive] && !HighLine.new.agree('> Do you want to run? (y/n): ', '')

    deploy_client.exec(options[:service])
  end

  desc 'slack-greeting-test', 'Slack bot says Hello'
  def slack_greeting_test
    ::Genova::Slack::Greeting.hello
    @logger.info('Sent message.')
  end

  desc 'github-pushed-test', 'Emulate GitHub push'
  option :account, required: false, desc: 'GitHub account'
  option :branch, required: false, default: 'master', aliases: :b, desc: 'Specify branch name.'
  option :repository, required: true, aliases: :r, desc: 'GitHub repository.'
  def github_pushed_test
    account = options[:account] || Settings.github.account
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
    result = RestClient.post('http://localhost:3000/api/v1/github/push', payload_body, headers)

    @logger.info('Sent deploy notification to Slack.')
    @logger.info(result)
  end
end
