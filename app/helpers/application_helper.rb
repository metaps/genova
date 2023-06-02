module ApplicationHelper
  def type_tag(type)
    case type
    when DeployJob.type.find_value(:service)
      klass = 'is-info'
      readable_type = 'Service'
    when DeployJob.type.find_value(:scheduled_task)
      klass = 'is-warning'
      readable_type = 'Scheduled task'
    when DeployJob.type.find_value(:run_task)
      klass = 'is-success'
      readable_type = 'Run task'
    end

    "<span class=\"tag #{klass}\">#{readable_type}</span>"
  end
end
