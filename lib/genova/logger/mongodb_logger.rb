module Genova
  module Logger
    class MongodbLogger < ::Logger
      def initialize(id)
        @deploy_job = DeployJob.find(id)
        #        super(STDOUT)
      end

      def format_message(severity, _datetime, _progname, message)
        time = Time.new.utc.strftime('%Y-%m-%dT%H:%M:%S.%06d')
        @deploy_job.push(logs: "#{severity[0]}, [#{time} ##{$PROCESS_ID}]  #{severity} -- : #{message}")
        #       super(severity, datetime, progname, message)
      end
    end
  end
end
