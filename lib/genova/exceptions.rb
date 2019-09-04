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
    class ClusterNotFoundError < Error; end
    class ServiceNotFoundError < Error; end
    class TaskRunningError < Error; end
    class TaskDefinitionValidateError < Error; end
    class TaskStoppedError < Error; end
    class KmsEncryptError < Error; end
    class KmsDecryptError < Error; end
    class DeployTimeoutError < Error; end
  end
end
