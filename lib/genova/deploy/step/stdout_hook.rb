module Genova
  module Deploy
    module Step
      class StdoutHook
        def initialize
          @logger = ::Logger.new($stdout)
        end

        def start_step(params)
          @logger.info("Deploy step ##{params[:index]}.")
        end

        def start_deploy(_params)
          @logger.info('Start deployment.')
        end

        def complete_deploy(_params)
          @logger.info('Deployment was successful.')
        end

        def complete_steps(_params)
          @logger.info('All deployments are complete.')
        end
      end
    end
  end
end
