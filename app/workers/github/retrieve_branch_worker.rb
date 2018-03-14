module Github
  class RetrieveBranchWorker
    include Sidekiq::Worker

    sidekiq_options queue: :detect_branches, retry: false

    def perform(account, repository, response_url)
      logger.info('Started Github::RetrieveBranchWorker')

      query = {
        account: account,
        repository: repository
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
              options: Genova::Slack::Util.branch_options(account, repository),
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
      RestClient.post(response_url, data.to_json)
    end
  end
end
