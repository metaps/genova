require 'open3'

module Genova
  module Command
    class Executor
      def initialize(options = {})
        @work_dir = options[:work_dir]
        @logger = options[:logger] || ::Logger.new(nil)
      end

      def command(command, chdir = nil)
        outputs = []

        begin
          @logger.info("$ #{command}")

          work_dir = chdir.present? ? chdir : @work_dir
          Dir.chdir(work_dir) if work_dir.present?

          Open3.popen3(command) do |i, o, e|
            i.write
            i.close

            o.each do |line|
              line.chomp!
              @logger.info(line)
              outputs << line
            end

            e.each do |line|
              line.chomp!
              @logger.error(line)
              outputs << line
            end
          end

          outputs.join("\n")
        rescue Interrupt
          message = 'command was forcibly terminated.'
          @logger.error(message)
          raise Interrupt, message
        rescue => e
          @logger.error(e.to_s)
          raise e
        end
      end
    end
  end
end
