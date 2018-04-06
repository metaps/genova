module Github
  class RetrieveBranchWorker
    include Sidekiq::Worker

    sidekiq_options queue: :detect_branches, retry: false

    WAIT_INTERVAL = 3
    WAIT_LONG_TIME = 5

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      job = Genova::Sidekiq::Queue.find(id)
      job.update(status: Genova::Sidekiq::Queue.status.find_value(:in_progress))

      query = {
        account: job.account,
        repository: job.repository
      }
      callback_id = Genova::Slack::CallbackIdBuilder.build('post_branch', query)

      data = {
        channel: ENV.fetch('SLACK_CHANNEL'),
        response_type: 'in_channel',
        replace_original: false,
        attachments: [
          text: 'Target branch.',
          color: Settings.slack.message.color.interactive,
          attachment_type: 'default',
          callback_id: callback_id,
          actions: [
            {
              name: 'branch',
              text: 'Pick a branch...',
              type: 'select',
              options: Genova::Slack::Util.branch_options(job.account, job.repository),
              selected_options: [
                {
                  text: 'master',
                  value: 'master'
                }
              ]
            },
            {
              name: 'submit',
              text: 'Approve',
              type: 'button',
              style: 'primary',
              value: 'approve'
            },
            {
              name: 'submit',
              text: 'Cancel',
              type: 'button',
              style: 'default',
              value: 'cancel'
            }
          ]
        ]
      }

      RestClient.post(job.response_url, data.to_json)
      job.update(status: Genova::Sidekiq::Queue.status.find_value(:complete))
    end
  end
end
