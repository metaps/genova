module Genova
  module Exceptions
    class Error < StandardError; end
    class ValidationError < Error; end
    class InvalidRequestError < Error; end
    class NotFoundError < Error; end
    class DeployLockError < Error; end
    class RoutingError < Error; end
    class InvalidArgumentError < Error; end
    class OutputError < Error; end
  end
end
