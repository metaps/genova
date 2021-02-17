module Genova
  class TransactionManager
    LOCK_WAIT_INTERVAL = 10

    def initialize(repository)
      @key = "deploy-lock_#{ENV.fetch('GITHUB_ACCOUNT')}:#{repository}"
      @logger = ::Logger.new($stdout, level: Settings.logger.level)
      @repository = repository
    end

    def begin
      @logger.info("Begin transaction: #{@repository}")

      waiting_time = 0

      while running?
        raise Exceptions::DeployLockError, "Other deployment is in progress. [#{@deploy_job.repository}]" if waiting_time >= Settings.github.deploy_lock_timeout

        @logger.warn("Deploy locked. Retry in #{LOCK_WAIT_INTERVAL} seconds.")

        sleep(LOCK_WAIT_INTERVAL)
        waiting_time += LOCK_WAIT_INTERVAL
      end

      Redis.current.multi do
        Redis.current.setnx(@key, true)
        Redis.current.expire(@key, Settings.github.deploy_lock_timeout)
      end
    end

    def running?
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
