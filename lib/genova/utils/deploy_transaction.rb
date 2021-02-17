module Genova
  module Utils
    class DeployTransaction
      LOCK_WAIT_INTERVAL = 10

      def initialize(repository, logger)
        @key = "deploy-lock_#{ENV.fetch('GITHUB_ACCOUNT')}:#{repository}"
        @logger = logger
        @repository = repository
      end

      def begin
        @logger.info("Begin transaction: #{@repository}")

        waiting_time = 0

        while exist?
          if waiting_time >= Settings.github.deploy_lock_timeout
            raise Exceptions::DeployLockError, "Other deployment is in progress. [#{@deploy_job.repository}]"
          end

          @logger.warn("Deploy locked. Retry in #{LOCK_WAIT_INTERVAL} seconds.")

          sleep(LOCK_WAIT_INTERVAL)
          waiting_time += LOCK_WAIT_INTERVAL
        end

        Redis.current.multi do
          Redis.current.setnx(@key, true)
          Redis.current.expire(@key, Settings.github.deploy_lock_timeout)
        end
      end

      def exist?
        Redis.current.get(@key) || false
      end

      def commit
        @logger.info("Commit transaction: #{@repository}")
        Redis.current.del(@key)
      end

      def cancel
        @logger.info("Cancel transaction: #{@repository}")
        Redis.current.del(@key)
      end
    end
  end
end
