module Github
  class RetrieveBranchWatchWorker
    include Sidekiq::Worker

    sidekiq_options queue: :github_retrieve_branch_watch, retry: false

    WAIT_INTERVAL = 1
    ELAPSED_TIME = 5

    def perform(id)
      logger.info('Started Github::RetrieveBranchWatchWorker')

      job = Genova::Sidekiq::Queue.find(id)
      start_time = Time.new.utc.to_i

      loop do
        break if job.status == Genova::Sidekiq::Queue.status.find_value(:complete)

        sleep(WAIT_INTERVAL)

        next if Time.new.utc.to_i - start_time < ELAPSED_TIME
        job = Genova::Sidekiq::Queue.find(id)

        if job.status == Genova::Sidekiq::Queue.status.find_value(:in_progress)
          bot = Genova::Slack::Bot.new
          bot.post_simple_message(text: 'Retrieving repository. Please wait...')
        end

        break
      end
    end
  end
end
