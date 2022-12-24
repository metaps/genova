module Genova
  module Deploy
    module Workflow
      class Runner
        class << self
          def call(name, params, callback)
            workflows = Settings.workflows || []
            workflow = workflows.find { |k| k[:name].include?(name) }
            raise Exceptions::ValidationError, "Workflow '#{name}' is undefined." if workflow.nil?

            Genova::Deploy::Step::Runner.call(workflow[:steps], params, callback)
          end
        end
      end
    end
  end
end
