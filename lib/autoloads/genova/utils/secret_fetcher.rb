module Genova
  module Utils
    class SecretFetcher
      class << self
        def call(secret_id)
          return if secret_id.blank?

          if secret_id.start_with?('arn:aws:secretsmanager:')
            Aws::SecretsManager::Client.new.get_secret_value(secret_id: secret_id).secret_string
          else
            Aws::SSM::Client.new.get_parameter(name: secret_id, with_decryption: true).parameter.value
          end
        end
      end
    end
  end
end
