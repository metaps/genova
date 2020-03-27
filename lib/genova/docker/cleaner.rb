module Genova
  module Docker
    class Cleaner
      class << self
        def execute
          @logger = ::Logger.new(STDOUT)
          @logger.info('Start cleanup')

          cleanup_containers
          cleanup_images
          cleanup_networks
          cleanup_volumes
        end

        private

        def cleanup_containers
          @logger.info('Cleanup unused containers')

          ::Docker::Container.all(all: true).each do |container|
            if container.info['State'] == 'exited'
              @logger.info("  #{container.id}")
              container.remove
            end
          end
        end

        def cleanup_images
          @logger.info('Cleanup unused images')
          used_images = []

          ::Docker::Container.all(all: true).each do |container|
            used_images << container.info['ImageID']
          end

          used_images.uniq!
          current_time = Time.new.utc.to_i
          retention_sec = Settings.docker.retention_days * 60 * 60 * 24
          ecr_image_key = "#{Aws::STS::Client.new.get_caller_identity[:account]}.dkr.ecr.#{ENV.fetch('AWS_REGION')}.amazonaws.com"
          ecr_image_key = Genova::Ecr::Client.base_path

          ::Docker::Image.all.each do |image|
            next if current_time - image.info['Created'] <= retention_sec

            image.info['RepoTags'].each do |repo_tag|
              next if used_images.include?(image.id)

              values = repo_tag.split(':')

              if repo_tag == '<none>:<none>'
                @logger.info("  #{image.id}")
                image.remove
              elsif values[0].include?(ecr_image_key)
                @logger.info("  #{image.id}")
                image.remove(name: repo_tag, force: true)
              end
            end
          end
        end

        def cleanup_networks
          @logger.info('Cleanup unused networks')
          ::Docker::Network.prune
        end

        def cleanup_volumes
          @logger.info('Cleanup unused volumes')
          ::Docker::Volume.prune
        end
      end
    end
  end
end
