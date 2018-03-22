module API
  class Route < Grape::API
    # /api
    prefix :api
    format :json

    logger.formatter = GrapeLogging::Formatters::Default.new
    use GrapeLogging::Middleware::RequestLogger, logger: logger

    log_file = File.open('log/grape.log', 'a')
    log_file.sync = true
    logger Logger.new GrapeLogging::MultiIO.new(STDOUT, log_file)

    rescue_from :all do |e|
      logger.fatal(e.to_s + ':' + e.backtrace.to_s)

      bot = Genova::Slack::Bot.new
      bot.post_error(error: e)

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

    mount V1::Routes
  end
end
