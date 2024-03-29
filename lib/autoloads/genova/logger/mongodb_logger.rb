module Genova
  module Logger
    class MongodbLogger < ::Logger
      def initialize(deploy_job)
        @deploy_job = deploy_job
        super($stdout)
      end

      def format_message(severity, datetime, progname, message)
        time = Time.new.utc.strftime('%Y-%m-%dT%H:%M:%S.%06d')
        @deploy_job.push(logs: "#{severity[0]}, [#{time} ##{$PROCESS_ID}]  #{severity} -- : #{message}")
        super(severity, datetime, progname, message)
      end
    end
  end
end
