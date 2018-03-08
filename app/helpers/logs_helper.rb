module LogsHelper
  def task_revision(task_definition_arn)
    return if task_definition_arn.nil?

    task_definition_arn.match(/:([0-9]+)$/)[1]
  end
end
