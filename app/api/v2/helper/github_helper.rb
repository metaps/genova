module V2
  module Helper
    module GithubHelper
      extend Grape::API::Helpers

      def verify_signature?(payload)
        return false unless request.env['HTTP_X_HUB_SIGNATURE']

        sha1 = OpenSSL::Digest.new('sha1')
        signature = 'sha1=' + OpenSSL::HMAC.hexdigest(sha1, ENV.fetch('GITHUB_SECRET_KEY'), payload)
        payload.present? && Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
      end

      def parse(payload)
        data = Oj.load(payload, symbol_keys: true)
        return if data[:ref].nil?

        matches = data[:ref].match(%r{^refs/([^/]+)/(.+)$})

        # タグのプッシュは検知対象外
        return raise Genova::Exceptions::InvalidRequestError, "#{data[:ref]} is not a valid request." if matches.nil? || matches[1] != 'heads'

        full_name = data[:repository][:full_name].split('/')

        result = {
          account: full_name[0],
          repository: full_name[1],
          commit_url: data[:head_commit][:url],
          author: data[:head_commit][:author][:username]
        }
        result[:branch] = matches[2]
        result
      end
    end
  end
end
