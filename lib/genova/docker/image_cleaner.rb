module Genova
  module Docker
    class ImageCleaner
      class << self
        def call
          logger = ::Logger.new($stdout, level: Settings.logger.level)
          logger.info('Cleanup unused images')

          used_images = []

          ::Docker::Container.all(all: true).each do |container|
            used_images << container.info['ImageID']
          end

          used_images.uniq!
          current_time = Time.new.utc.to_i
          retention_sec = Settings.docker.retention_days * 60 * 60 * 24

          ::Docker::Image.all.each do |image|
            next if image.info.dig('Labels', Genova::Docker::Client::BUILD_KEY).nil?
            next if current_time - image.info['Created'] <= retention_sec

            image.info['RepoTags'].each do |repo_tag|
              next if used_images.include?(image.id)

              logger.info("  #{image.id}")

              if repo_tag == '<none>:<none>'
                image.remove
              else
                image.remove(name: repo_tag, force: true)
              end
            end
          end
        end
      end
    end
  end
end
