class GenovaDebug < Thor
  no_commands do
    def invoke_command(command, *args)
      @logger = Logger.new(STDOUT)
      super
    end
  end

  desc 'slack-greeting', 'Slack bot says Hello'
  def slack_greeting
    ::Genova::Slack::Bot.new.post_simple_message(message: 'Hello')
    @logger.info('Sent message.')
  end

  desc 'github-push', 'Emulate GitHub push'
  option :account, required: false, default: Settings.github.account, desc: 'GitHub account'
  option :repository, required: true, aliases: :r, desc: 'Source repository.'
  option :branch, required: false, default: Settings.github.default_branch, aliases: :b, desc: 'Source branch.'
  def github_push
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

  desc 'update-source', 'Retrieve latest source'
  option :account, required: false, default: Settings.github.account, desc: 'GitHub account'
  option :repository, required: true, aliases: :r, desc: 'Source repository.'
  option :branch, required: false, default: Settings.github.default_branch, aliases: :b, desc: 'Source branch.'
  def update_source
    manager = ::Genova::Git::LocalRepositoryManager.new(options[:account], options[:repository], options[:branch])
    manager.update
  end
end
