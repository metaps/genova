module Genova
  module Ecr
    class Client
      BATCH_DELETE_MAX_IMAGE_SIZE = 100
      IMAGE_TAG_LATEST = 'latest'.freeze

      def initialize(params)
        @ecr = Aws::ECR::Client.new(profile: params[:profile], region: params[:region])
        @registry = ENV.fetch('AWS_ACCOUNT_ID') + '.dkr.ecr.ap-northeast-1.amazonaws.com'

        @logger = params[:logger] || ::Logger.new(STDOUT)

        ::Docker.options[:read_timeout] = Settings.aws.service.ecr.read_timeout
        ::Docker.logger = @logger
      end

      def authenticate
        authorization_token = @ecr.get_authorization_token[:authorization_data][0][:authorization_token]
        result = Base64.strict_decode64(authorization_token).split(':')
        ::Docker.authenticate!(username: result[0], password: result[1], serveraddress: "https://#{@registry}")
      end

      def push_image(tag_revision, repository_name)
        repositories = @ecr.describe_repositories[:repositories]

        if repositories.find { |item| item[:repository_name] == repository_name }.nil?
          raise ImagePushError, "Repository '#{repository_name}' does not exist in ECR."
        end

        repo_tag_latest = "#{@registry}/#{repository_name}:#{IMAGE_TAG_LATEST}"
        repo_tag_version = "#{@registry}/#{repository_name}:#{tag_revision}"

        image = ::Docker::Image.get(repository_name)
        image.tag(repo: "#{@registry}/#{repository_name}", tag: IMAGE_TAG_LATEST)
        image.tag(repo: "#{@registry}/#{repository_name}", tag: tag_revision)

        image.push(nil, repo_tag: repo_tag_latest)
        @logger.info("Pushed image. {\"tag\": #{repo_tag_latest}}")

        image.push(nil, repo_tag: repo_tag_version)
        @logger.info("Pushed image. {\"tag\": #{repo_tag_version}}")
      end

      def cleanup_image(repository_name)
        images = {}
        next_token = nil

        loop do
          describe_images = @ecr.describe_images(
            repository_name: repository_name,
            next_token: next_token
          )
          describe_images.image_details.each do |image|
            images[image.image_pushed_at.to_i] = {
              image_digest: image.image_digest
            }
          end

          next_token = describe_images.next_token
          break if next_token.nil?
        end

        images = images.sort.reverse
        images.slice!(0, Settings.aws.service.ecr.max_image_size)

        image_ids = []
        images.each do |_key, value|
          image_ids << value
        end

        return if image_ids.empty?

        if image_ids.size > BATCH_DELETE_MAX_IMAGE_SIZE
          image_ids = image_ids.slice(- BATCH_DELETE_MAX_IMAGE_SIZE, BATCH_DELETE_MAX_IMAGE_SIZE)
        end

        results = @ecr.batch_delete_image(
          repository_name: repository_name,
          image_ids: image_ids
        )

        results.image_ids.each do |image|
          @logger.info("Delete image. {\"digest\": #{image.image_digest}}")
        end

        results.failures.each do |failure|
          @logger.error('Failed to delete image. {' \
            "\"reason\": #{failure.failure_reason}, " \
            "\"code\": #{failure.failure_code}, " \
            "\"digest\": #{failure.image_id.image_digest}" \
            '}')
        end
      end
    end
  end
end
