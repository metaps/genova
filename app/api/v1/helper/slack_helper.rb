module V1
  module Helper
    module SlackHelper
      extend Grape::API::Helpers

      def verify_signature?
        data = payload_to_json
        data[:token].present? && data[:token] == ENV.fetch('SLACK_VERIFICATION_TOKEN')
      end

      def payload_to_json
        return {} if params[:payload].blank?

        Oj.load(params[:payload], symbol_keys: true)
      end
    end
  end
end
