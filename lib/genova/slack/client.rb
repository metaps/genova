module Genova
  module Slack
    BASE ='https://slack.com/api/'

    class Client
      def self.get(endpoint, params = {})
        response = RestClient::Request.execute(
          method: 'get',
          url: "#{BASE}/#{endpoint}",
          headers: {
            Authorization: "Bearer #{ENV.fetch('SLACK_API_TOKEN')}",
            params: params
          }
        )
        Oj.load(response.body, symbol_keys: true)
      end
    end
  end
end
