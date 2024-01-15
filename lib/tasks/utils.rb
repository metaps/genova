module GenovaCli
  class Utils < Thor
    namespace :utils

    desc 'delete-invalid-jobs', 'Delete invalid and inconsistent jobs (jobs older than 1 week).'
    long_desc 'This task is usually performed by cron, so there is no need to do it manually.'
    def delete_invalid_jobs
      DeployJob.delete_invalid_jobs
    end

    desc 'delete-old-images', 'Delete the old image used by genova for build.'
    long_desc 'This task is usually performed by cron, so there is no need to do it manually.'
    def delete_old_images
      ::Genova::Docker::ImageCleaner.call
    end

    desc 'delete-transaction', 'Cancel deploy transactions.'
    option :repository, required: true, aliases: :r, desc: 'Repository name.'
    def delete_transaction
      transaction = ::Genova::Deploy::Transaction.new(options[:repository])

      if transaction.running?
        transaction.cancel
        puts('Transaction has been cancelled.')
      else
        puts('Transaction does not exist.')
      end
    end

    desc 'register-task', 'Register task definition.'
    option :branch, default: Settings.github.default_branch, aliases: :b, desc: 'Branch name.'
    option :path, required: true, desc: 'Task path.'
    option :repository, required: true, aliases: :r, desc: 'Repository name.'
    def register_task
      code_manager = ::Genova::CodeManager::Git.new(options[:repository], branch: options[:branch])
      code_manager.update

      path = code_manager.task_definition_config_path(options[:path])
      task = ::Genova::Ecs::Task::Client.new.register(path, nil, tag: 'latest')

      puts("Registered task. [#{task.task_definition_arn}]")
    end

    desc 'encrypt', 'Encrypt a string specified in the argument using KMS (now deprecated).'
    option :alias, desc: 'KMS alias name.'
    option :key_id, desc: 'KMS key id.'
    option :value, required: true, desc: 'Value to encrypt.'
    def encrypt
      raise ::Genova::Exceptions::ValidationErrorError, "Either 'alias' or 'key_id' is required." unless options[:alias] || options[:key_id]

      key_id = options[:alias] ? "alias/#{options[:alias]}" : options[:key_id]

      cipher = ::Genova::Utils::Cipher.new(Logger.new($stdout))
      value = cipher.encrypt(key_id, options[:value])

      puts "Encrypted value: #{value}"
    end

    desc 'decrypt', 'Decrypt a value encrypted with KMS (now deprecated).'
    option :value, required: true, desc: 'Value to decrypt.'
    def decrypt
      cipher = ::Genova::Utils::Cipher.new(Logger.new($stdout))
      value = cipher.decrypt(options[:value])

      puts "Decrypted value: #{value}"
    end
  end
end
