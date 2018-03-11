module Genova
  module Slack
    class RequestHandler
      class << self
        def handle_request(payload_body, logger)
          return if payload_body.blank?

          @payload_body = payload_body
          @logger = logger

          @bot = Genova::Slack::Bot.new
          @id_builder = Genova::Slack::CallbackIdBuilder.new(CGI.unescapeHTML(@payload_body[:callback_id]))

          execute
        end

        def execute
          case @id_builder.uri.path
          when 'post_history' then
            result = confirm_deploy_from_history
          when 'post_repository' then
            result = choose_deploy_branch
          when 'post_branch' then
            result = choose_deploy_service
          when 'post_service' then
            result = confirm_deploy
          when 'post_deploy' then
            result = execute_deploy
          else
            raise 'No route.'
          end

          result
        end

        private

        def choose_deploy_branch
          selected_value = @payload_body.dig(:actions, 0, :selected_options, 0, :value)

          if selected_value.present?
            result = "Repository: #{selected_value}"
            split = selected_value.split('/')

            @logger.info('Invoke Github::RetrieveBranchWorker')
            @logger.info("account: #{split[0]}, repository: #{split[1]}, response_url: #{@payload_body[:response_url]}")

            ::Github::RetrieveBranchWorker.perform_async(split[0], split[1], @payload_body[:response_url])
          else
            result = 'Cancelled.'
          end

          result
        end

        def choose_deploy_service
          submit_value = @payload_body.dig(:actions, 0, :value)

          if submit_value == 'approve' || submit_value.nil?
            selected_value = @payload_body.dig(:actions, 0, :selected_options, 0, :value) || 'master'
            result = 'Branch: ' + selected_value
            query = @id_builder.query

            @bot.post_choose_deploy_service(query[:account], query[:repository], selected_value)
          else
            result = 'Cancelled.'
          end

          result
        end

        def confirm_deploy
          selected_value = @payload_body.dig(:actions, 0, :selected_options, 0, :value) || 'development'
          result = 'Service: ' + selected_value
          query = @id_builder.query

          @bot.post_confirm_deploy(query[:account], query[:repository], query[:branch], selected_value)

          result
        end

        def confirm_deploy_from_history
          selected_value = @payload_body.dig(:actions, 0, :selected_options, 0, :value)
          slack_user_id = @payload_body[:user][:id]

          if selected_value.present?
            value = Genova::Deploy::History.new(slack_user_id).find(selected_value)
            result = "Repository: #{value[:account]}/#{value[:repository]}\n" \
                     "Branch: #{value[:branch]}\n" \
                     "Service: #{value[:service]}"

            @bot.post_confirm_deploy(value[:account], value[:repository], value[:branch], value[:service])

          else
            result = 'Cancelled.'
          end

          result
        end

        def execute_deploy
          selected_value = @payload_body.dig(:actions, 0, :value)

          if selected_value == 'approve'
            result = "Confirm: #{selected_value}"
            query = @id_builder.query

            account = query[:account]
            repository = query[:repository]
            branch = query[:branch]
            service = query[:service]

            @logger.info('Invoke Slack::DeployWorker')
            @logger.info("account: #{account}, repository: #{repository}, branch: #{branch}, service: #{service}")

            @bot.post_deploy_queue

            id = DeployJob.generate_id
            DeployJob.create(id: id,
                             status: Genova::Deploy::Client.status.find_value(:in_progress).to_s,
                             mode: Genova::Deploy::Client.mode.find_value(:slack).to_s,
                             slack_user_id: @payload_body[:user][:id],
                             slack_user_name: @payload_body[:user][:name],
                             account: account,
                             repository: repository,
                             branch: branch,
                             service: service)

            ::Slack::DeployWorker.perform_async(id)
          else
            result = 'Cancelled.'
          end

          result
        end
      end
    end
  end
end
