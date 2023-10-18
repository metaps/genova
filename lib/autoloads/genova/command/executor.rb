require 'open3'

module Genova
  module Command
    class Executor
      class << self
        def call(command, logger, options = {})
          @logger = logger
          @options = options

          begin
            wait_for_execute(command)
          rescue Interrupt
            @logger.error('Detected forced termination of program.')
            raise Interrupt
          rescue => e
            @logger.error(e.message)
            raise e
          end
        end

        def wait_for_execute(command)
          @logger.info("Execute command. [#{command}]")

          Dir.chdir(@options[:work_dir]) if @options[:work_dir].present?
          Open3.popen3(command) do |stdin, stdout, stderr|
            stdin.close_write

            loop do
              IO.select([stdout, stderr]).flatten.compact.each do |io|
                io.each do |line|
                  next if line.nil? || line.empty?

                  @logger.info(line.chomp)
                end
              end

              break if stdout.eof? && stderr.eof?
            end
          end
        end
      end
    end
  end
end
