require 'open3'

module Genova
  module Command
    class Executor
      class << self
        def call(command, logger, options = {})
          begin
            status = wait_for_execute(command, logger, options)
            status.exitstatus
          rescue Interrupt
            logger.error('Detected forced termination of program.')
            raise Interrupt
          rescue => e
            logger.error(e.message)
            raise e
          end
        end

        private

        def write_stdin(stdin, stdin_data)
          begin
            stdin.write(stdin_data) unless stdin_data.nil?
          ensure
            stdin.close_write
          end
        rescue Errno::EPIPE
          # The child closed stdin early; still collect its output and exit status.
        end

        def handle_io(stdin, stdout, stderr, logger, stdin_data)
          write_stdin(stdin, stdin_data)

          loop do
            IO.select([stdout, stderr]).flatten.compact.each do |io|
              io.each do |line|
                next if line.nil? || line.empty?

                logger.info(line.chomp)
              end
            end

            break if stdout.eof? && stderr.eof?
          end
        end

        def wait_for_execute(command, logger, options)
          logger.info("Execute command. [#{options[:filtered_command].presence || command}]")

          exit_status = nil

          Open3.popen3(*Array(command)) do |stdin, stdout, stderr, wait_thr|
            handle_io(stdin, stdout, stderr, logger, options[:stdin_data])
            exit_status = wait_thr.value
          end

          exit_status
        end
      end
    end
  end
end
