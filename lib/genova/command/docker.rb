module Genova
  module Command
    class Docker
      class << self
        def gc
          runtime = RuntimeCommand::Builder.new

          # Delete suspended container.
          command = 'docker rm `docker ps -a -q`'
          runtime.exec(command)

          # Delete <none> images.
          command = 'docker rmi $(docker images | awk \'/^<none>/ { print $3 }\')'
          runtime.exec(command)

          # Delete pushed images. (1 weeks ago)
          command = 'docker rmi $(docker images | ' \
                    "grep #{ENV.fetch('AWS_ACCOUNT_ID')} | " \
                    'grep \'weeks ago\' | ' \
                    'awk \'{ printf "%s:%s\n", $1, $2 }\')'
          runtime.exec(command)
        end
      end
    end
  end
end
