module Genova
  module Ecr
    class Client
      IMAGE_TAG_LATEST = 'latest'.freeze

      def initialize(params = {})
        @ecr = Aws::ECR::Client.new
        @logger = params[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
        @base_path = base_path

        ::Docker.options[:read_timeout] = Settings.ecr.read_timeout
        ::Docker.logger = @logger
      end

      def authenticate
        authorization_token = @ecr.get_authorization_token[:authorization_data][0][:authorization_token]
        username, password = Base64.strict_decode64(authorization_token).split(':')
        ::Docker.authenticate!(username:, password:, serveraddress: "https://#{@base_path}")
      end

      def push_image(image_tag, repository_name)
        next_token = nil
        has_repository = false

        loop do
          results = @ecr.describe_repositories(next_token:)
          next_token = results[:next_token]

          if results[:repositories].find { |item| item[:repository_name] == repository_name }.present?
            has_repository = true
            break
          end

          break if next_token.nil?
        end

        unless has_repository
          raise Exceptions::ValidationError, "Repository does not exist. [#{repository_name}]" unless Settings.ecr.create_repository

          @ecr.create_repository(repository_name:) unless has_repository

        end

        repo_tag_latest = "#{@base_path}/#{repository_name}:#{IMAGE_TAG_LATEST}"
        repo_tag_version = "#{@base_path}/#{repository_name}:#{image_tag}"

        image = ::Docker::Image.get(repository_name)
        image.tag(repo: "#{@base_path}/#{repository_name}", tag: IMAGE_TAG_LATEST)
        image.tag(repo: "#{@base_path}/#{repository_name}", tag: image_tag)

        image.push(nil, repo_tag: repo_tag_latest)
        @logger.info("Push the built image to the ECR. [#{repo_tag_latest}]")

        image.push(nil, repo_tag: repo_tag_version)
        @logger.info("Push the built image to the ECR. [#{repo_tag_version}]")
      end

      private

      def base_path
        account = ENV.fetch('AWS_ACCOUNT_ID', '')
        account = Aws::STS::Client.new.get_caller_identity[:account] if account.blank?

        "#{account}.dkr.ecr.#{ENV.fetch('AWS_REGION')}.amazonaws.com"
      end
    end
  end
end
