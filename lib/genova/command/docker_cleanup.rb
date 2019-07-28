module Genova
  module Command
    class DockerCleanup
      class << self
        def exec
          @logger = ::Logger.new(STDOUT)
          @executor = Genova::Command::Executor.new(logger: @logger)

          cleanup_stopped_images
          cleanup_dangling_images
          cleanup_old_images
        end

        def cleanup_stopped_images
          @logger.info('Cleanup stopped container.')

          result = @executor.command('docker container prune -f')
          @logger.info(result)
        end

        def cleanup_dangling_images
          @logger.info('Cleanup dangling images.')

          result = @executor.command('docker image prune -f')
          @logger.info(result)
        end

        def cleanup_old_images
          @logger.info('Cleanup old images.')

          result = @executor.command('docker images --format "{{.ID}}|{{.Repository}}|{{.CreatedAt}}"')

          current_time = Time.new.utc.to_i
          image_cleanup_interval = Settings.docker.image_cleanup_interval * 60 * 60 * 24
          match_key = "#{Aws::STS::Client.new.get_caller_identity[:account]}.dkr.ecr.#{ENV.fetch('AWS_REGION')}.amazonaws.com"
          deleted_images = 0

          result.split("\n").each do |row|
            columns = row.split('|')

            next unless current_time - Time.parse(columns[2]).to_i > image_cleanup_interval && columns[1].match(/#{match_key}/)

            result = @executor.command("docker rmi -f #{columns[0]}")
            deleted_images += 1
            @logger.info(result)
          end

          @logger.info("Deleted #{deleted_images} images.")
        end
      end
    end
  end
end
