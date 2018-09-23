module Github
  class RetrieveBranchWatchWorker
    include Sidekiq::Worker

    sidekiq_options queue: :github_retrieve_branch_watch, retry: false

    WAIT_INTERVAL = 1
    NOTIFY_THRESHOLD = 10

    def perform(id)
      logger.info('Started Github::RetrieveBranchWatchWorker')

      start_time = Time.new.utc.to_i

      loop do
        sleep(WAIT_INTERVAL)

        # RetrieveBranchWorkerの処理が一定時間を超えた場合にSlack通知
        next if Time.new.utc.to_i - start_time < NOTIFY_THRESHOLD

        workers = Sidekiq::Workers.new
        workers.each do |_process_id, _thread_id, work|
          next unless work['payload'][:jid] == jid

          bot = Genova::Slack::Bot.new
          bot.post_simple_message(text: 'Retrieving repository. Please wait...')
        end

        break
      end
    end
  end
end
