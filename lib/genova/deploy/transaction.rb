module Genova
  module Deploy
    class Transaction
      LOCK_WAIT_INTERVAL = 10

      def initialize(repository, options = {})
        @key = "trans_#{Settings.github.account}:#{repository}"
        @repository = repository
        @logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
      end

      def begin
        @logger.info('Begin transaction.')

        waiting_time = 0

        while running?
          raise Exceptions::DeployLockError, 'Transaction conflict release wait timed out.' if waiting_time >= Settings.github.deploy_lock_timeout

          sleep(LOCK_WAIT_INTERVAL)
          waiting_time += LOCK_WAIT_INTERVAL

          @logger.warn("Wait #{LOCK_WAIT_INTERVAL} seconds for the lock to be released because there is already a transaction running. (Elapsed time: #{waiting_time}s)")
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
        @logger.info('Complete the transaction.')
        Redis.current.del(@key)
      end

      def cancel
        @logger.info('Cancel transaction.')
        Redis.current.del(@key)
      end
    end
  end
end
