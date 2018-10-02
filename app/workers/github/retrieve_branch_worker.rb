module Github
  class RetrieveBranchWorker
    include Sidekiq::Worker

    sidekiq_options queue: :github_retrieve_branch, retry: false

    def perform(id)
      logger.info('Started Github::RetrieveBranchWorker')

      job = Genova::Sidekiq::Queue.find(id)
      params = {
        account: job.account,
        repository: job.repository
      }
      callback_id = Genova::Slack::CallbackIdManager.create('choose_deploy_cluster', params)
      options = Genova::Slack::Util.branch_options(job.account, job.repository)

      data = {
        channel: ENV.fetch('SLACK_CHANNEL'),
        response_type: 'in_channel',
        replace_original: false,
        attachments: [
          title: 'Target branch.',
          color: Settings.slack.message.color.interactive,
          attachment_type: 'default',
          callback_id: callback_id,
          actions: [
            {
              name: 'branch',
              text: 'Pick a branch...',
              type: 'select',
              options: options,
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
    end
  end
end
