module Genova
  module Exceptions
    class Error < StandardError; end

    class ValidationError < Error; end

    class InvalidRequestError < Error; end

    class NotFoundError < Error; end

    class DeployLockError < Error; end

    class RoutingError < Error; end

    class InvalidArgumentError < Error; end

    class RunTaskError < Error; end

    class TaskDefinitionValidationError < Error; end

    class TaskStoppedError < Error; end

    class KmsEncryptError < Error; end

    class KmsDecryptError < Error; end

    class DeployTimeoutError < Error; end

    class ImageBuildError < Error; end

    class SlackEventsAPIError < Error; end

    class SlackWebAPIError < Error; end

    class SlackPermissionDeniedError < Error; end

    class UnexpectedError < Error; end

    class MigrationError < Error; end
  end
end
