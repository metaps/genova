module Github
  class RetrieveBranchWatchWorker < BaseWorker
    sidekiq_options queue: :github_retrieve_branch_watch, retry: false

    WAIT_INTERVAL = 1
    NOTIFY_THRESHOLD = 5

    def perform(id)
      logger.info('Started Github::RetrieveBranchWatchWorker')

      start_time = Time.new.utc.to_i
      workers = Sidekiq::Workers.new

      jid =  Genova::Slack::SessionStore.new(id).params[:retrieve_branch_jid]

      loop do
        sleep(WAIT_INTERVAL)
        elapsed_time = Time.new.utc.to_i - start_time

        logger.info("Elapsed time: #{elapsed_time}s...")

        # RetrieveBranchWorkerの処理が一定時間を超えた場合にSlack通知
        next if elapsed_time < NOTIFY_THRESHOLD

        workers.each do |_process_id, _thread_id, worker|
          next unless worker['payload']['jid'] == jid

          bot = Genova::Slack::Bot.new(parent_message_ts: id)
          bot.post_simple_message(text: 'Retrieving repository. Please wait...')
        end

        break
      end

    rescue => e
      slack_notify(e, jid)
      raise e
    end
  end
end
