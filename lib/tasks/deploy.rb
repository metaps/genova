module GenovaCli
  class Deploy < Thor
    namespace :deploy

    class_option :'no-cache', desc: 'Build the image without caching.'
    class_option :branch, aliases: :b, desc: 'Branch to deploy.'
    class_option :force, default: false, type: :boolean, aliases: :f, desc: 'If true is specified, it forces a deployment.'
    class_option :interactive, default: false, type: :boolean, aliases: :i, desc: 'Show confirmation message before deploying.'
    class_option :tag, desc: 'Tag to deploy.'
    class_option :note, desc: 'Arbitrary text to attach to the deploy job.'
    class_option :verbose, default: false, type: :boolean, aliases: :v, desc: 'Outputting detailed logs.'
    class_option :build_only, default: false, type: :boolean, desc: 'Register the task definition and push images without deploying.'

    no_commands do
      def linux_user_name
        @linux_user_name ||= begin
          user = ENV['GENOVA_DEPLOY_USER'].to_s.strip
          if user.empty?
            # Keep stdin attached to the caller's terminal: who am i uses it to
            # find the original login session, even after switching users.
            output = IO.popen(['who', 'am', 'i'], err: File::NULL, &:read)
            $?.success? ? (output.split.first || 'unknown') : 'unknown'
          else
            user
          end
        rescue SystemCallError, IOError
          'unknown'
        end
      end

      def prepare(options)
        options[:branch] = Settings.github.default_branch if options[:branch].nil? && options[:tag].nil?
        return if options[:repository].nil? || options[:target].nil?

        code_manager = ::Genova::CodeManager::Git.new(
          options[:repository],
          branch: options[:branch],
          tag: options[:tag]
        )
        code_manager.update
        options.merge!(code_manager.deploy_config.find_target(options[:target]))
      end

      def deploy(options)
        executor = linux_user_name
        if options[:build_only] && (options[:override_container].present? || options[:override_command].present?)
          raise ::Genova::Exceptions::InvalidArgumentError, '--build-only cannot be combined with --override-container or --override-command.'
        end
        validate_note!(options[:note])
        prompt = options[:build_only] ? '> Do you want to build and push images without deploying? (y/n): ' : '> Do you want to deploy? (y/n): '
        return if options[:interactive] && !HighLine.new.agree(prompt, '')

        prepare(options)
        repository_settings = ::Genova::Config::SettingsHelper.find_repository(options[:repository])

        deploy_job = DeployJob.new(
          id: DeployJob.generate_id,
          mode: DeployJob.mode.find_value(:manual).to_sym,
          linux_user_name: executor,
          build_only: options[:build_only] == true,
          type: options[:type],
          alias: repository_settings.present? ? repository_settings[:alias] : nil,
          account: Settings.github.account,
          branch: options[:branch],
          tag: options[:tag],
          cluster: options[:cluster],
          service: options[:service],
          scheduled_task_rule: options[:scheduled_task_rule],
          scheduled_task_target: options[:scheduled_task_target],
          repository: repository_settings.present? ? repository_settings[:name] : options[:repository],
          run_task: options[:run_task],
          override_container: options[:override_container],
          override_command: options[:override_command],
          note: options[:note]
        )

        raise ::Genova::Exceptions::ValidationError, deploy_job.errors.full_messages[0] unless deploy_job.save

        params = {
          verbose: options[:verbose],
          force: options[:force],
          no_cache: options.key?(:'no-cache')
        }

        ::Genova::Deploy::Runner.new(deploy_job, params).run
      end

      def validate_note!(note)
        return unless DeployJob.note_required? && note.blank?

        raise ::Genova::Exceptions::InvalidArgumentError, 'Note must be specified.'
      end
    end

    desc 'run-task', 'Execute run task.'
    option :cluster, aliases: :c, default: 'default', desc: 'Cluster to deploy.'
    option :override_container, desc: 'Container name to override'
    option :override_command, desc: 'Command to override'
    option :run_task, desc: 'Name of task to execute.'
    option :repository, required: true, aliases: :r, desc: 'Repository name or alias name.'
    option :target, aliases: :t, desc: 'Target to deploy. (https://github.com/metaps/genova/wiki/Deploy-target)'
    def run_task
      raise ::Genova::Exceptions::InvalidArgumentError, 'Task or target must be specified.' if options[:run_task].blank? && options[:target].blank?

      hash_options = options.to_hash.symbolize_keys
      hash_options[:type] = DeployJob.type.find_value(:run_task)

      deploy(hash_options)
    end

    desc 'service', 'Update service task.'
    option :cluster, aliases: :c, default: 'default', desc: 'Cluster to deploy.'
    option :repository, required: true, aliases: :r, desc: 'Repository name or alias name.'
    option :service, aliases: :s, desc: 'Service to deploy.'
    option :target, aliases: :t, desc: 'Target to deploy. (https://github.com/metaps/genova/wiki/Deploy-target)'
    def service
      raise ::Genova::Exceptions::InvalidArgumentError, 'Service or target must be specified.' if options[:service].blank? && options[:target].blank?

      hash_options = options.to_hash.symbolize_keys
      hash_options[:type] = DeployJob.type.find_value(:service)

      deploy(hash_options)
    end

    desc 'scheduled-task', 'Update scheduled task.'
    option :cluster, aliases: :c, default: 'default', desc: 'Cluster to deploy.'
    option :scheduled_task_rule, desc: 'Schedule rule to deploy.'
    option :scheduled_task_target, desc: 'Schedule target to deploy.'
    option :repository, required: true, aliases: :r, desc: 'Repository name or alias name.'
    option :target, aliases: :t, desc: 'Target to deploy. (https://github.com/metaps/genova/wiki/Deploy-target)'
    def scheduled_task
      raise ::Genova::Exceptions::InvalidArgumentError, 'Scheduled task or target must be specified.' if (options[:scheduled_task_rule].blank? || options[:scheduled_task_target].blank?) && options[:target].blank?

      hash_options = options.to_hash.symbolize_keys
      hash_options[:type] = DeployJob.type.find_value(:scheduled_task)

      deploy(hash_options)
    end

    desc 'workflow', 'Execute step deployment using workflow.'
    option :name, requred: true, aliases: :n, desc: 'Workflow name to deploy.'
    def workflow
      executor = linux_user_name
      validate_note!(options[:note])

      ::Genova::Deploy::Workflow::Runner.call(
        options[:name],
        ::Genova::Deploy::Step::StdoutHook.new,
        mode: DeployJob.mode.find_value(:manual),
        linux_user_name: executor,
        force: options[:force],
        build_only: options[:build_only],
        no_cache: options.key?(:'no-cache'),
        note: options[:note]
      )
    end
  end
end
