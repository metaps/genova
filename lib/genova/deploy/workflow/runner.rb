module Genova
  module Deploy
    module Workflow
      class Runner
        class << self
          def call(name, callback, options)
            workflows = Settings.workflows || []

            workflow = workflows.find { |k| k[:name].include?(name) }
            raise Exceptions::ValidationError, "Workflow is undefined. [#{name}]" if workflow.nil?

            Step::Runner.call(workflow[:steps], callback, options)
          end
        end
      end
    end
  end
end
