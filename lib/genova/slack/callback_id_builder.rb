module Genova
  module Slack
    class CallbackIdBuilder
      attr_reader :uri, :query

      def initialize(callback_id)
        @uri = URI.parse(callback_id)
        @query = @uri.query.present? ? Hash[URI.decode_www_form(@uri.query)].symbolize_keys : {}
      end

      def self.build(callback_id, query = {})
        callback_id = URI(callback_id)
        callback_id.query = query.to_param

        result = callback_id.to_s
        raise CallbackIdBuildError.new('Failed to generate Callback ID. Character string exceeds 200 characters.') if result.size > 200

        result
      end
    end

    class CallbackIdBuildError < Error; end
  end
end
