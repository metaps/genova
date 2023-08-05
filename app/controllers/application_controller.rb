class ApplicationController < ActionController::Base
  rescue_from Exception, with: :render_500 if Rails.env.production?

  protect_from_forgery with: :exception

  def render_404
    @title = '404 Page Not Found'
    render template: 'errors/error', status: 404, layout: 'application'
  end

  def render_500(error)
    logger.fatal(error.message)
    logger.fatal(error.backtrace.join("\n"))

    @title = '500 Internal Server error'
    render template: 'errors/error', status: 500, layout: 'application'
  end
end
