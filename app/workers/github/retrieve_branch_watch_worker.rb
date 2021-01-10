module Github
  class RetrieveBranchWatchWorker
    include Sidekiq::Worker

    sidekiq_options queue: :github_retrieve_branch_watch, retry: false

    WAIT_INTERVAL = 1
    NOTIFY_THRESHOLD = 5

    def perform(id)
      logger.info('Started Github::RetrieveBranchWatchWorker')

      start_time = Time.new.utc.to_i
      workers = Sidekiq::Workers.new

      loop do
        sleep(WAIT_INTERVAL)
        elapsed_time = Time.new.utc.to_i - start_time

        logger.info("Elapsed time: #{elapsed_time}s...")

        # RetrieveBranchWorkerの処理が一定時間を超えた場合にSlack通知
        next if elapsed_time < NOTIFY_THRESHOLD

        workers.each do |_process_id, _thread_id, worker|
          next unless worker['payload']['jid'] == id

          bot = Genova::Slack::Bot.new
          bot.post_simple_message(text: 'Retrieving repository. Please wait...')
        end

        break
      end
    end
  end
end
