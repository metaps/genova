module Genova
  module Docker
    class ImageCleaner
      RETENTION_SEC = Settings.docker.retention_days * 60 * 60 * 24

      class << self
        def call
          logger = ::Logger.new($stdout, level: Settings.logger.level)
          logger.info('Cleanp unused images.')

          images = using_images

          ::Docker::Image.all.each do |image|
            next unless deletable?(image)

            image.info['RepoTags'].each do |repo_tag|
              next if images.include?(image.id)

              logger.info("  #{image.id}")

              if repo_tag == '<none>:<none>'
                image.remove
              else
                image.remove(name: repo_tag, force: true)
              end
            end
          end

          logger.info('Successful cleanup of the image.')
        end

        private

        def using_images
          images = []

          ::Docker::Container.all(all: true).each do |container|
            images << container.info['ImageID']
          end

          images.uniq!
          images
        end

        def deletable?(image)
          return false if image.info['RepoTags'].nil?
          return false if image.info.dig('Labels', Genova::Docker::Client::BUILD_KEY).nil? && image.info['RepoTags'][0] != '<none>:<none>'
          return false if Time.new.utc.to_i - image.info['Created'] <= RETENTION_SEC

          true
        end
      end
    end
  end
end
