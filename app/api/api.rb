module API
  class Route < Grape::API
    format :json

    logger.formatter = GrapeLogging::Formatters::Default.new
    use GrapeLogging::Middleware::RequestLogger, logger: logger

    logger Logger.new(STDOUT, level: Settings.logger.level)

    rescue_from :all do |e|
      logger.fatal(e.message)
      logger.fatal(e.full_message)

      Genova::Slack::Bot.new.post_error(error: e)

      error! e, 500
    end

    helpers do
      def logger
        Route.logger
      end
    end

    # /api
    get do
      { result: 'success' }
    end

    mount V2::Routes
  end
end
