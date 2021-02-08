module V2
  class Routes < Grape::API
    # /api/v2
    version 'v2'

    mount V2::GithubRoutes
    mount V2::SlackRoutes
  end
end
