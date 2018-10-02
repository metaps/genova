module V1
  module Helper
    module GithubHelper
      extend Grape::API::Helpers

      def verify_signature?(payload_body)
        return false unless request.env['HTTP_X_HUB_SIGNATURE']

        sha1 = OpenSSL::Digest.new('sha1')
        signature = 'sha1=' + OpenSSL::HMAC.hexdigest(sha1, ENV.fetch('GITHUB_SECRET_KEY'), payload_body)
        payload_body.present? && Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
      end

      def parse(payload_body)
        data = Oj.load(payload_body, symbol_keys: true)
        matches = data[:ref].match(%r{^refs/([^/]+)/(.+)$})

        # タグのプッシュは検知対象外
        return raise ParseError, 'Request are ignored.' if matches.nil? || matches[1] != 'heads'

        full_name = data[:repository][:full_name].split('/')

        result = {
          account: full_name[0],
          repository: full_name[1]
        }
        result[:branch] = matches[2]
        result
      end

      class ParseError < Genova::Error; end
    end
  end
end
