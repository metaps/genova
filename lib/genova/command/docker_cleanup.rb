module Genova
  module Command
    class DockerCleanup
      class << self
        def exec
          @logger = Logger.new(STDOUT)

          cleanup_stopped_images
          cleanup_dangling_images
          cleanup_old_images
        end

        def cleanup_stopped_images
          @logger.info('Delete suspended container.')

          command = 'docker container prune -f'
          @logger.info(command)
          result = Genova::Command.exec(command)
          @logger.info(result)
        end

        def cleanup_dangling_images
          @logger.info('Delete <none> images.')

          command = 'docker image prune -f'
          @logger.info(command)
          result = Genova::Command.exec(command)
          @logger.info(result)
        end

        def cleanup_old_images
          @logger.info('Delete old images.')

          command = 'docker images --format "{{.ID}}|{{.Repository}}|{{.CreatedAt}}"'
          @logger.info(command)

          result = Genova::Command.exec(command)
          @logger.info(result)

          current_time = Time.new.utc.to_i
          image_cleanup_interval = Settings.docker.image_cleanup_interval * 60 * 60 * 24
          match_key = "#{ENV.fetch('AWS_ACCOUNT_ID')}.dkr.ecr.#{ENV.fetch('AWS_REGION')}.amazonaws.com"

          result.split("\n").each do |row|
            columns = row.split('|')

            if current_time - Time.parse(columns[2]).to_i > image_cleanup_interval && columns[1].match(/#{match_key}/)
              command = "docker rmi #{columns[0]}"
              @logger.info(command)

              result = Genova::Command.exec(command)
              @logger.info(result)
            end
          end
        end
      end
    end
  end
end
