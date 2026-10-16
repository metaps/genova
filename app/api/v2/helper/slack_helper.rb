module V2
  module Helper
    module SlackHelper
      extend Grape::API::Helpers

      SIGNATURE_VERSION = 'v0'.freeze
      TIMESTAMP_TOLERANCE = 60 * 5

      # https://api.slack.com/authentication/verifying-requests-from-slack
      def verify_signature?
        signing_secret = Settings.slack.signing_secret
        timestamp = request.env['HTTP_X_SLACK_REQUEST_TIMESTAMP']
        signature = request.env['HTTP_X_SLACK_SIGNATURE']

        return false if signing_secret.blank? || timestamp.blank? || signature.blank?
        return false unless timestamp.match?(/\A\d+\z/)
        return false if (Time.now.to_i - timestamp.to_i).abs > TIMESTAMP_TOLERANCE

        base_string = "#{SIGNATURE_VERSION}:#{timestamp}:#{raw_body}"
        expected = "#{SIGNATURE_VERSION}=#{OpenSSL::HMAC.hexdigest('SHA256', signing_secret, base_string)}"

        Rack::Utils.secure_compare(expected, signature)
      end

      def payload_to_hash
        return {} if params[:payload].blank?

        Oj.load(params[:payload], symbol_keys: true)
      end

      private

      def raw_body
        input = request.env['rack.input']
        return '' if input.nil?

        input.rewind
        body = input.read
        input.rewind

        body
      end
    end
  end
end
