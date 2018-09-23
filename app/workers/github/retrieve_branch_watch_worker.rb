module Github
  class RetrieveBranchWatchWorker
    include Sidekiq::Worker

    sidekiq_options queue: :github_retrieve_branch_watch, retry: false

    WAIT_INTERVAL = 1
    NOTIFY_THRESHOLD = 10

    def perform(id)
      logger.info('Started Github::RetrieveBranchWatchWorker')

      elapsed_time = Time.new.utc.to_i

      loop do
        sleep(WAIT_INTERVAL)

        # RetrieveBranchWorkerの処理が一定時間を超えた場合にSlackへ通知
        break if Time.new.utc.to_i - elapsed_time < NOTIFY_THRESHOLD

        workers = Sidekiq::Workers.new
        workers.each do |process_id, thread_id, work|
          next unless work['payload'][:jid] == jid

          bot = Genova::Slack::Bot.new
          bot.post_simple_message(text: 'Retrieving repository. Please wait...')
        end

        break
      end
    end
  end
end
