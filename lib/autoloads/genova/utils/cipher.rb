module Genova
  module Utils
    class Cipher
      VARIABLE_PATTERN = /^\${(.+)}$/

      def initialize(logger)
        @logger = logger
        @kms_client = Aws::KMS::Client.new
      end

      def encrypt(master_key, value)
        encode = @kms_client.encrypt(key_id: "alias/#{master_key}", plaintext: value)
        "${#{Base64.strict_encode64(encode.ciphertext_blob)}}"
      rescue => e
        raise Exceptions::KmsEncryptError, e.to_s
      end

      def decrypt(value)
        @logger.info("Decrypt value: #{value}")

        match = value.match(VARIABLE_PATTERN)
        raise Exceptions::KmsDecryptError, 'Encrypted string is invalid.' unless match

        begin
          @kms_client.decrypt(ciphertext_blob: Base64.strict_decode64(match[1])).plaintext
        rescue => e
          raise Exceptions::KmsDecryptError, e.to_s
        end
      end

      def encrypt_format?(value)
        value.to_s.match?(VARIABLE_PATTERN) ? true : false
      end
    end
  end
end
