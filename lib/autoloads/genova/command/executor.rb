module Genova
  module Command
    class Executor
      class << self
        def call(command, logger, options = {})
          @logger = logger
          @options = options

          begin
            status = wait_for_execute(command)
            status.exitstatus
          rescue Interrupt
            @logger.error('Detected forced termination of program.')
            raise Interrupt
          rescue => e
            @logger.error(e.message)
            raise e
          end
        end

        private

        def handle_io(stdin, stdout, stderr)
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

        def wait_for_execute(command)
          @logger.info("Execute command. [#{@options[:filtered_command].presence || command}]")

          exit_status = nil
          Dir.chdir(@options[:work_dir]) if @options[:work_dir].present?

          Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
            handle_io(stdin, stdout, stderr)
            exit_status = wait_thr.value
          end

          exit_status
        end
      end
    end
  end
end
