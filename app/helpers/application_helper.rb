module ApplicationHelper
  def readable_type(type)
    case type
    when DeployJob.type.find_value(:service)
      'Service'
    when DeployJob.type.find_value(:scheduled_task)
      'Scheduled task'
    when DeployJob.type.find_value(:run_task)
      'Run task'
    end
  end
end
