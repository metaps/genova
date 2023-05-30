module Genova
  module Slack
    class Client
      ENDPOINT_BASE = 'https://slack.com/api/'.freeze

      def self.get(endpoint, params = {})
        response = RestClient::Request.execute(
          method: 'get',
          url: "#{ENDPOINT_BASE}/#{endpoint}",
          headers: {
            Authorization: "Bearer #{Settings.slack.api_token}",
            params:
          }
        )
        Oj.load(response.body, symbol_keys: true)
      end
    end
  end
end
