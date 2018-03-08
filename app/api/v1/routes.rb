module V1
  class Routes < Grape::API
    # /api/v1
    version 'v1'

    mount V1::GithubRoutes
    mount V1::SlackRoutes
  end
end
