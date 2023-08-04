module Genova
  module Deploy
    class Transaction
      LOCK_WAIT_INTERVAL = 10

      def initialize(repository, options = {})
        @key = "trans_#{Settings.github.account}:#{repository}"
        @repository = repository
        @logger = options[:logger] || ::Logger.new($stdout, level: Settings.logger.level)
        @force = options[:force]
      end

      def begin
        cancel if @force

        @logger.info('Begin transaction.')

        waiting_time = 0

        while running?
          raise Exceptions::DeployLockError, 'Transaction conflict release wait timed out.' if waiting_time >= Settings.github.deploy_lock_timeout

          sleep(LOCK_WAIT_INTERVAL)
          waiting_time += LOCK_WAIT_INTERVAL

          @logger.warn("Wait #{LOCK_WAIT_INTERVAL} seconds for the lock to be released because there is already a transaction running. (Elapsed time: #{waiting_time}s)")
        end

        Genova::RedisPool.get.multi do
          Genova::RedisPool.get.setnx(@key, true)
          Genova::RedisPool.get.expire(@key, Settings.github.deploy_lock_timeout)
        end
      end

      def running?
        Genova::RedisPool.get.get(@key) || false
      end

      def commit
        @logger.info('Complete the transaction.')
        Genova::RedisPool.get.del(@key)
      end

      def cancel
        return unless running?

        @logger.info('Cancel transaction.')
        Genova::RedisPool.get.del(@key)
      end
    end
  end
end
