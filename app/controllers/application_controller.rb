class ApplicationController < ActionController::Base
  rescue_from Exception, with: :render_500 if Rails.env.production?

  protect_from_forgery with: :exception

  def render_404(exception = nil)
    if exception
      logger.fatal(exception.to_s)
      logger.fatal(exception.backtrace)
    end

    @title = '404 Page Not Found'
    render template: 'errors/error', status: 404, layout: 'application'
  end

  def render_500(exception = nil)
    if exception
      logger.fatal(exception.to_s)
      logger.fatal(exception.backtrace)
    end

    @title = '500 Internal Server Error'
    render template: 'errors/error', status: 500, layout: 'application'
  end
end
