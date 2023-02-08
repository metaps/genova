module Genova
  module Sidekiq
    class ErrorHandler
      class << self
        def notify(error, _context_hash)
          ::Sidekiq.logger.error(error)
        end
      end
    end
  end
end
