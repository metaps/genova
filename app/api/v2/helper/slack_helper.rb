module V2
  module Helper
    module SlackHelper
      extend Grape::API::Helpers

      def verify_signature?
        data = payload_to_hash

        # https://github.com/metaps/genova/issues/407
        data.include?(:token) && data[:token] == Settings.slack.vertification_token || data.include?(:token) && data[:token] == Settings.slack.verification_token
      end

      def payload_to_hash
        return {} if params[:payload].blank?

        Oj.load(params[:payload], symbol_keys: true)
      end
    end
  end
end
