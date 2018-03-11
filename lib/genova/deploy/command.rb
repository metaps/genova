module Genova
  module Deploy
    class Command
      def initialize(options = {})
        @work_dir = options[:work_dir]
        @logger = options[:logger].nil? ? Logger.new(STDOUT) : options[:logger]
      end

      def exec(command, work_dir = nil)
        results = {
          stdout: '',
          stderr: ''
        }

        begin
          work_dir = @work_dir if work_dir.nil?
          @logger.info(command)

          Open3.popen3(command, chdir: work_dir) do |stdin, stdout, stderr|
            stdin.close

            stdout.each do |message|
              @logger.info(message.chop)
              results[:stdout] << message
            end

            stderr.each do |message|
              @logger.error(message.chop)
              results[:stderr] << message
            end
          end

          results
        rescue Interrupt
          @logger.error('Command exectuion canceled.')
          raise Interrupt, 'Command execution canceled.'
        rescue => e
          @logger.error(e.to_s)
          raise e
        end
      end
    end
  end
end
