module Genova
  module Deploy
    module Workflow
      class Runner
        class << self
          def call(name, options, callback)
            workflows = Settings.workflows || []
            workflow = workflows.find { |k| k[:name].include?(name) }
            raise Exceptions::ValidationError, "Workflow is undefined. [#{name}]" if workflow.nil?

            Genova::Deploy::Step::Runner.call(workflow[:steps], options, callback)
          end
        end
      end
    end
  end
end
