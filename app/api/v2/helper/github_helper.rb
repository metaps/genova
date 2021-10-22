module V2
  module Helper
    module GithubHelper
      extend Grape::API::Helpers

      def verify_webhook_signature?(payload)
puts '>>>>'
puts request.env['HTTP_X_HUB_SIGNATURE']

        return false unless request.env['HTTP_X_HUB_SIGNATURE']

        digest = OpenSSL::Digest.new('sha1')
        signature = "sha1=#{OpenSSL::HMAC.hexdigest(digest, ENV.fetch('GITHUB_SECRET_KEY'), payload)}"
        payload.present? && Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
      end

      def parse_webhook_data(data)

        {
          account: data[:repository][:owner][:name],
          repository: data[:repository][:name],
          branch: parse_branch(data[:ref]),
          commit_url: data[:head_commit][:url],
          author: data[:head_commit][:author][:username]
        }
      end

      def verify_actions_secret_key?
        ENV.fetch('GITHUB_SECRET_KEY') == request.env['HTTP_X_GITHUB_SECRET_KEY']
      end

      def parse_actions_data(data)
        {
          account: data[:account],
          repository: data[:repository],
          branch: parse_branch(data[:ref]),
          commit_url: data[:commit_url],
          author: data[:author]
        }
      end

      private

      def parse_branch(ref)
        raise Genova::Exceptions::InvalidRequestError, 'Request does not contain "ref" attribute.' if ref.nil?
        matches = ref.match(%r{^refs/([^/]+)/(.+)$})

        # Excludes tag push
        raise Genova::Exceptions::InvalidRequestError, "#{ref} is not a valid request." if matches.nil? || matches[1] != 'heads'

        matches[2]
      end
    end
  end
end
