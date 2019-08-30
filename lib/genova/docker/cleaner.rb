module Genova
  module Docker
    class Cleaner
      class << self
        def exec
          @logger = ::Logger.new(STDOUT)

          if Settings.docker.cleanup
             @logger.info('Start cleanup')

             cleanup_unused_containers
             cleanup_unused_images
             cleanup_unused_networks
             cleanup_unused_volumes
          else
            @logger.info('Cleanup is disabled')
          end
        end

        def cleanup_unused_containers
          @logger.info('Cleanup unused containers')

          ::Docker::Container.all(all: true).each do |container|
            if container.info["State"] == 'exited'
              @logger.info("  #{container.id}")
              container.remove
            end
          end
        end

        def cleanup_unused_images
          @logger.info('Cleanup unused images')
          used_images = []

          ::Docker::Container.all.each do |container|
            used_images << container.info['ImageID']
          end

          used_images.uniq!
          current_time = Time.new.utc.to_i
          image_cleanup_interval = Settings.docker.image_cleanup_interval * 60 * 60 * 24
          ecr_image_key = "#{Aws::STS::Client.new.get_caller_identity[:account]}.dkr.ecr.#{ENV.fetch('AWS_REGION')}.amazonaws.com"

          ::Docker::Image.all.each do|image|
            remove_target = if image.info['RepoTags'][0] === '<none>:<none>'
              true
            elsif current_time - image.info['Created'] > image_cleanup_interval && image.info['RepoTags'][0].include?(ecr_image_key)
              true
            else
              false
            end

            if remove_target && !used_images.include?(image.info['id'])
              @logger.info("  #{image.id}")
              image.remove(name: image.info['RepoTags'][0], force: true)
            end
          end
        end

        def cleanup_unused_networks
          @logger.info('Cleanup unused networks')
          ::Docker::Network.prune
        end

        def cleanup_unused_volumes
          @logger.info('Cleanup unused volumes')
          ::Docker::Volume.prune
        end
      end
    end
  end
end
