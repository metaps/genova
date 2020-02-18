module Genova
  module Ecr
    class Client
      IMAGE_TAG_LATEST = 'latest'.freeze

      def self.base_path
        account = ENV.fetch('AWS_ACCOUNT_ID', '')
        account = Aws::STS::Client.new.get_caller_identity[:account] if account.blank?

        "#{account}.dkr.ecr.#{ENV.fetch('AWS_REGION')}.amazonaws.com"
      end

      def initialize(params = {})
        @ecr = Aws::ECR::Client.new
        @logger = params[:logger] || ::Logger.new(nil)
        @base_path = Client.base_path

        ::Docker.options[:read_timeout] = Settings.aws.service.ecr.read_timeout
        ::Docker.logger = @logger
      end

      def authenticate
        authorization_token = @ecr.get_authorization_token[:authorization_data][0][:authorization_token]
        result = Base64.strict_decode64(authorization_token).split(':')
        ::Docker.authenticate!(username: result[0], password: result[1], serveraddress: "https://#{@base_path}")
      end

      def push_image(image_tag, repository_name)
        repositories = @ecr.describe_repositories[:repositories]

        @ecr.create_repository(repository_name: repository_name) if repositories.find { |item| item[:repository_name] == repository_name }.nil?

        repo_tag_latest = "#{@base_path}/#{repository_name}:#{IMAGE_TAG_LATEST}"
        repo_tag_version = "#{@base_path}/#{repository_name}:#{image_tag}"

        image = ::Docker::Image.get(repository_name)
        image.tag(repo: "#{@base_path}/#{repository_name}", tag: IMAGE_TAG_LATEST)
        image.tag(repo: "#{@base_path}/#{repository_name}", tag: image_tag)

        image.push(nil, repo_tag: repo_tag_latest)
        @logger.info("Pushed image. {\"tag\": #{repo_tag_latest}}")

        image.push(nil, repo_tag: repo_tag_version)
        @logger.info("Pushed image. {\"tag\": #{repo_tag_version}}")
      end
    end
  end
end
