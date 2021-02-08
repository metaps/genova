module Genova
  module Ecs
    DeployResponse = Struct.new(:task_definition_arn, :task_arns) { ; }
  end
end
