module V2
  module Helper
    module GithubHelper
      extend Grape::API::Helpers

      def verify_signature?(payload)
        return false unless request.env['HTTP_X_HUB_SIGNATURE']

        digest = OpenSSL::Digest.new('sha1')
        signature = "sha1=#{OpenSSL::HMAC.hexdigest(digest, ENV.fetch('GITHUB_SECRET_KEY'), payload)}"
        payload.present? && Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
      end

      def parse(payload)
        data = Oj.load(payload, symbol_keys: true)
        raise Genova::Exceptions::InvalidRequestError, 'Request does not contain "ref" attribute.' if data[:ref].nil?

        matches = data[:ref].match(%r{^refs/([^/]+)/(.+)$})

        # Excludes tag push
        raise Genova::Exceptions::InvalidRequestError, "#{data[:ref]} is not a valid request." if matches.nil? || matches[1] != 'heads'

        # Exclude commits that don't belong to any branch
        raise Genova::Exceptions::InvalidRequestError, 'Commit does not belong to any branch' if data[:head_commit].nil?

        account, repository = data[:repository][:full_name].split('/')

        {
          account: account,
          repository: repository,
          branch: matches[2],
          commit_url: data[:head_commit][:url],
          author: data[:head_commit][:author][:username]
        }
      end
    end
  end
end
