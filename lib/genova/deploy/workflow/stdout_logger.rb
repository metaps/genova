module Genova
  module Deploy
    module Workflow
      class StdoutLogger
        def initialize
          @logger = ::Logger.new($stdout)
        end

        def start_step(params)
          @logger.info("Start Deployment Step ##{params[:index]}.")
        end

        def start_deploy(params)
        end

        def finished_deploy(_params)
          @logger.info('Finished deployment step.')
        end

        def finished_all_deploy
          @logger.info('All deployments are complete.')
        end
      end
    end
  end
end
