module Genova
  module Deploy
    module Workflow
      class StdoutLogger
        def initialize
          @logger = ::Logger.new(STDOUT)
        end

        def step_start(id, _step)
          @logger.info("Start deployment step ##{id}.")
        end

        def step_finished(_deploy_job)
          @logger.info("Finished deployment step.")
        end

        def step_all_finished
          @logger.info('All deployments are complete.')
        end
      end
    end
  end
end