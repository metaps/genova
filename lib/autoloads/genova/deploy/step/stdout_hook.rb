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

        def start_deploy(_params); end

        def complete_deploy(_params); end

        def complete_steps(params)
          @logger.info(params[:build_only] ? 'All builds and ECR pushes are complete. No deployment was performed.' : 'All deployments are complete.')
        end
      end
    end
  end
end
